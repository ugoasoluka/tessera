# Tessera Coding Agent Platform

A Slack-based coding assistant that orchestrates LLM-driven code changes through durable Temporal workflows on AWS EKS, opens GitHub pull requests, and posts the result back to the originating Slack thread. Built for the Tessera Labs take-home assignment.

> **TL;DR.** User mentions the bot in Slack → bot starts a Temporal workflow whose ID is the Slack thread → a Pydantic AI agent reads the repo, writes commits to a per-thread branch, opens a PR → bot replies in the thread with the PR link. Concurrent threads are isolated by workflow ID. See [`DESIGN.md`](./DESIGN.md) for decisions, trade-offs, and future improvements.

## Architecture

```mermaid
flowchart LR
  user(["Slack user"]) -->|@mention in thread| slack["Slack workspace"]
  slack -- "Socket Mode<br/>(outbound WS)" --> bot

  subgraph eks["AWS EKS — VPC 10.0.0.0/16"]
    subgraph apps["ns: tessera-apps"]
      bot["slack-bot"]
      worker["temporal-worker<br/>(Pydantic AI agent)"]
    end
    subgraph temporal_ns["ns: temporal"]
      tfront["temporal-frontend"]
      tweb["temporal-web UI"]
    end
  end

  bot -- "start_workflow" --> tfront
  worker -- "poll task queue" --> tfront
  tfront -- "TLS" --> rds[("RDS Postgres")]
  worker -- "API" --> github[("GitHub repo")]
  worker -- "post thread reply" --> slack

  classDef ext fill:#1f2937,color:#e5e7eb,stroke:#374151;
  class user,slack,github,rds ext;
```

## Repository layout

```
.
├── DESIGN.md                   # decisions, trade-offs, limitations, future work
├── README.md                   # this file
├── apps/
│   ├── slack-bot/              # Bolt + Socket Mode → Temporal client
│   └── temporal-worker/        # Pydantic AI agent + Temporal worker
├── helm/
│   ├── external-secrets/       # External Secrets Operator (deps: charts.external-secrets.io)
│   ├── temporal/               # Temporal server (deps: go.temporal.io/helm-charts)
│   ├── slack-bot/              # in-house chart for the bot
│   └── temporal-worker/        # in-house chart for the worker
├── terraform/
│   ├── bootstrap/              # S3 + DynamoDB for the remote backend
│   └── main/                   # VPC, EKS, RDS, ECR, IAM (incl. GitHub OIDC), Secrets Manager
└── .github/workflows/
    └── build-and-push.yml      # GitHub Actions → OIDC → ECR push
```

## Required stack (per the assignment)

| Stack item | Where it lives |
|---|---|
| Pydantic AI | `apps/temporal-worker/src/temporal_worker/agent.py` |
| Slack App (free workspace) | `apps/slack-bot/`, configured for Socket Mode |
| Temporal | `helm/temporal/` (community chart) + `apps/temporal-worker/` |
| AWS EKS | `terraform/main/eks.tf` |
| Terraform | `terraform/{bootstrap,main}/` |
| Helm | `helm/{external-secrets,temporal,slack-bot,temporal-worker}/` |
| GitHub integration | `apps/temporal-worker/src/temporal_worker/github.py` (real PR creation, not mock) |

---

## Prerequisites

- AWS account + an AWS profile with admin (or close to it) for the initial provision. Region is `us-east-2`.
- A free Slack workspace and a Slack app with **Socket Mode enabled**, scopes `app_mentions:read`, `chat:write`, `channels:history`, plus an app-level token (`xapp-…`). The bot token is `xoxb-…`.
- A GitHub repo the agent can PR into, plus a fine-grained PAT with `Contents: Read & Write` and `Pull requests: Read & Write` on that repo.
- A Google AI Studio API key for `gemini-2.0-flash`.
- Local tools: `terraform >= 1.5`, `kubectl`, `helm >= 3.13`, `aws` CLI v2, `docker` (only if you want to build images locally — CI does this for you).

---

## Install

The repo expects to be cloned somewhere convenient and the AWS CLI to have credentials in the chosen profile.

```bash
git clone https://github.com/ugoasoluka/tessera.git
cd tessera

aws sts get-caller-identity   # confirm your profile is right
aws configure set region us-east-2
```

---

## Deploy

The deploy is four passes: bootstrap → main infra → cluster add-ons → app charts. Each step is idempotent and re-runnable.

### 1. Bootstrap the Terraform remote backend

Creates the S3 state bucket and DynamoDB lock table that `terraform/main` uses.

```bash
cd terraform/bootstrap
terraform init
terraform apply
cd ../..
```

### 2. Apply the main infrastructure

Provisions VPC (3-tier subnets), EKS cluster + node group, RDS Postgres, ECR repos, IAM roles (including the GitHub Actions OIDC role), and the four AWS Secrets Manager entries with placeholder values.

```bash
cd terraform/main
terraform init
terraform apply
cd ../..
```

Capture two outputs you will need shortly:

```bash
terraform -chdir=terraform/main output github_actions_role_arn
# → arn:aws:iam::<acct>:role/tessera-gha-ecr-push   (paste into the GHA workflow)
```

Wire `kubectl` to the new cluster:

```bash
aws eks update-kubeconfig --region us-east-2 --name tessera
kubectl get nodes   # expect 2 Ready nodes
```

### 3. Populate the Secrets Manager values

Terraform created the secrets with `PLACEHOLDER_REPLACE_ME`. Fill them in:

```bash
for kv in \
  "tessera/slack-bot-token=xoxb-..." \
  "tessera/slack-app-token=xapp-..." \
  "tessera/anthropic-api-key=<your-gemini-or-llm-api-key>" \
  "tessera/github-pat=github_pat_..."; do
  name="${kv%%=*}"; value="${kv#*=}"
  aws secretsmanager put-secret-value --secret-id "$name" --secret-string "$value" >/dev/null
done
```

> The secret named `tessera/anthropic-api-key` actually holds the Gemini API key — historical naming, see DESIGN.md *Limitations*.

### 4. Install cluster add-ons

```bash
# External Secrets Operator (CRDs + controller)
helm dep update helm/external-secrets
helm upgrade --install tessera-external-secrets helm/external-secrets \
  -n external-secrets --create-namespace

# ClusterSecretStore + Temporal namespace + Temporal RDS-secret pull
kubectl apply -f helm/temporal/external-secret.yaml

# Temporal server (frontend, history, matching, web UI, schema-init job)
helm dep update helm/temporal
helm upgrade --install tessera-temporal helm/temporal \
  -n temporal --create-namespace --wait --timeout 10m
```

Wait for all Temporal pods to be `Running` (the schema-setup job will run, complete, and exit; that's expected):

```bash
kubectl -n temporal get pods -w
```

Create the `tessera` namespace inside Temporal so the apps can use it:

```bash
kubectl -n temporal exec deploy/tessera-temporal-admintools -- \
  temporal operator namespace create \
    --namespace tessera \
    --retention 7d \
    --address tessera-temporal-frontend:7233
```

### 5. Build & push the app images

Two options:

**(a) GitHub Actions (recommended).** Push the repo to GitHub. In `.github/workflows/build-and-push.yml`, replace `AWS_ROLE_ARN` with the value from step 2. Then in the GitHub UI, **Actions → Docker Image Build and Push → Run workflow**, pick `all`. The workflow assumes the OIDC role, builds both images on `linux/amd64`, and pushes daily-versioned tags (`v26.4.26`, `v26.4.26-1`, …) to ECR.

**(b) Local Docker.**

```bash
ACC=851276831101   # replace with yours
REGION=us-east-2
TAG=v0.1.0-$(git rev-parse --short HEAD)

aws ecr get-login-password --region $REGION | \
  docker login --username AWS --password-stdin $ACC.dkr.ecr.$REGION.amazonaws.com

for app in slack-bot temporal-worker; do
  docker build -t $ACC.dkr.ecr.$REGION.amazonaws.com/tessera-$app:$TAG apps/$app
  docker push    $ACC.dkr.ecr.$REGION.amazonaws.com/tessera-$app:$TAG
done
```

### 6. Install the app charts

Update the `image.tag` in each `values.yaml` to whatever was just pushed (`v26.4.26`, etc.) and the matching `appVersion` in each `Chart.yaml`. Then:

```bash
helm upgrade --install tessera-slack-bot       helm/slack-bot       -n tessera-apps --create-namespace
helm upgrade --install tessera-temporal-worker helm/temporal-worker -n tessera-apps
```

Watch:

```bash
kubectl -n tessera-apps get pods -w
```

You should see both pods reach `1/1 Running`. The worker logs `worker.connecting → worker.started` when it has connected to Temporal and is polling the task queue.

---

## Run

In the Slack workspace, invite the bot to a channel and mention it in a thread:

> @tessera-bot please add a CONTRIBUTING.md to the repo with a quick "how to open a PR" section

Expected sequence (you can watch it live):

```bash
# bot acks immediately, posts ":hammer_and_wrench: On it..." in the thread
kubectl -n tessera-apps logs -f deploy/tessera-slack-bot

# worker picks up the workflow, runs the agent, opens the PR
kubectl -n tessera-apps logs -f deploy/tessera-temporal-worker

# end state: PR link posted to the same Slack thread
```

To inspect the workflow execution itself:

```bash
kubectl -n temporal port-forward svc/tessera-temporal-web 8080:8080
# open http://localhost:8080  →  namespace "tessera"
# the workflow ID is slack-<team>-<channel>-<thread_ts>
```

Concurrent test (proves session isolation): open two threads in different channels and mention the bot in both nearly-simultaneously. Two distinct workflow executions appear in the UI with different IDs and independent histories.

---

## Cleanup

Reverse order of deploy. Helm releases first (so finalizers don't block the IAM role deletion later), then Terraform.

```bash
# Apps
helm uninstall tessera-slack-bot       -n tessera-apps
helm uninstall tessera-temporal-worker -n tessera-apps
kubectl delete namespace tessera-apps

# Cluster add-ons
kubectl delete -f helm/temporal/external-secret.yaml
helm uninstall tessera-temporal           -n temporal
helm uninstall tessera-external-secrets   -n external-secrets
kubectl delete namespace temporal external-secrets

# Drop ECR images first (IMMUTABLE repos won't tear down with images present)
for repo in tessera-slack-bot tessera-temporal-worker; do
  aws ecr batch-delete-image --region us-east-2 --repository-name $repo \
    --image-ids "$(aws ecr list-images --region us-east-2 --repository-name $repo --query 'imageIds[*]' --output json)" \
    >/dev/null 2>&1 || true
done

# Main infrastructure (VPC, EKS, RDS, ECR, IAM, Secrets Manager)
cd terraform/main
terraform destroy
cd ../..

# Backend (state bucket + lock table)
cd terraform/bootstrap
terraform destroy
cd ../..
```

> The Secrets Manager entries are removed by `terraform destroy`. If you want to wipe the values manually first, `aws secretsmanager delete-secret --secret-id tessera/<name> --force-delete-without-recovery`.

---

## Troubleshooting

A few real issues hit during the build of this submission, captured here so they are reproducible:

**Temporal schema-init pod stuck in `Init:CrashLoopBackOff` with `connect: connection timed out` against RDS.** Cause: the EKS launch template did not attach the custom worker security group, so pods egressed with the EKS-auto-cluster SG, which RDS's allow rule did not match. Fix: `vpc_security_group_ids = [aws_security_group.eks_worker.id]` on the launch template (already in this repo).

**Schema-init pod gets `pq: no pg_hba.conf entry … no encryption`.** RDS Postgres has `rds.force_ssl=1` by default. Fix: TLS enabled on both Temporal datastores in `helm/temporal/values.yaml` (`tls.enabled: true`, `enableHostVerification: false`).

**`temporal-worker` crashes on startup with `ImportError: cannot import name 'claw_state' from beartype.claw._clawstate`.** Pydantic AI's transitive deps install `beartype.claw` as a process-wide import hook that conflicts with Temporal's workflow sandbox. Fix: `workflow_runner=UnsandboxedWorkflowRunner()` in the worker's `main.py` (already applied). Long-term fix is to switch to `pydantic-ai-slim[google]` — see DESIGN.md.

**`Error: count … cannot be determined until apply`** during `terraform plan` on the ESO IRSA module. Cause: passing a `data.aws_iam_policy_document.json` (whose value depends on resource ARNs unknown at plan time) into a module that uses it for `count`. Fix: a separate `create_inline_policy = true` boolean argument on the module so `count` reads from a literal known at plan time (already applied).

---

## What lives in `DESIGN.md` instead of here

- Why Socket Mode and not the Events API
- Why one workflow run per Slack message instead of a long-lived workflow
- Why the agent runs inside one Temporal activity instead of per-tool activities
- Why the workflow sandbox is disabled
- The full privacy / session-isolation model
- The complete limitations + future-improvements lists

Read `DESIGN.md` first if you are reviewing for design quality rather than running the code.
