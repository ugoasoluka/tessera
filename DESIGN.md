# Tessera Coding Agent — Design Notes

## Goal

Build an enterprise-shaped Slack-based coding agent platform that:

1. Receives natural-language requests in Slack threads.
2. Coordinates the work through Temporal workflows.
3. Lets a Pydantic AI agent read, modify, and PR a GitHub repository.
4. Supports concurrent users with per-thread privacy and session isolation.
5. Runs on AWS EKS, provisioned with Terraform, packaged with Helm.

The submission is graded on **design quality, security, and clear documentation over completeness**, so this document leads with decisions and trade-offs.

---

## Architecture

```mermaid
flowchart LR
  user(["Slack user"]) -->|@mention in thread| slack["Slack workspace"]
  slack -- "Socket Mode<br/>(outbound WS)" --> bot

  subgraph eks["AWS EKS — VPC 10.0.0.0/16"]
    subgraph apps["ns: tessera-apps"]
      bot["slack-bot<br/>(Bolt + Socket Mode)"]
      worker["temporal-worker<br/>(Pydantic AI agent)"]
    end
    subgraph temporal_ns["ns: temporal"]
      tfront["temporal-frontend"]
      tmatch["temporal-matching"]
      thist["temporal-history"]
      tworker["temporal-worker (system)"]
      tweb["temporal-web UI"]
    end
    subgraph eso_ns["ns: external-secrets"]
      eso["External Secrets Operator<br/>(IRSA → Secrets Manager)"]
    end
  end

  bot -- "start_workflow<br/>(gRPC)" --> tfront
  worker -- "poll task queue<br/>(gRPC)" --> tfront
  tfront <--> tmatch
  tfront <--> thist
  thist -- "TLS" --> rds[("RDS Postgres<br/>(data subnets)")]

  worker -- "API" --> github[("GitHub<br/>repo")]
  worker -- "post thread reply" --> slack

  eso -. "sync every 1h" .-> sm[("AWS<br/>Secrets Manager")]
  bot -. "envFrom" .-> eso
  worker -. "envFrom" .-> eso

  classDef ext fill:#1f2937,color:#e5e7eb,stroke:#374151;
  class user,slack,github,sm,rds ext;
```

**Request flow** (one Slack mention end to end):

1. User mentions the bot in a Slack thread.
2. The Slack app (Socket Mode) delivers the event over an outbound WebSocket to the `slack-bot` pod.
3. The bot derives a deterministic workflow ID from the thread (`slack-{team}-{channel}-{thread_ts}`) and starts `CodingAgentWorkflow` on the Temporal frontend in-cluster.
4. The workflow's first activity is `run_agent`, executed on the `temporal-worker` pod. The activity drives a Pydantic AI loop with tools that read repo files, write commits to a per-workflow branch, and open a PR.
5. The workflow's second activity (`slack_post_thread_reply`) posts the result back to the originating Slack thread with retries.
6. Workflow history is durably persisted to Temporal's RDS Postgres backing store. Two threads in flight = two distinct workflow executions, isolated histories, isolated retries.

---

## Key decisions

### 1. Slack Socket Mode, not Events API webhooks

Socket Mode opens an outbound WebSocket from the bot pod to Slack. No public HTTPS endpoint, no ACM cert, no Route53 record, no signing-secret verification — Slack identifies the connection via the app-level token over TLS-secured WS.

Trade-off: marginally less idiomatic for "internet-scale" deployments. For a single-tenant internal bot it is the recommended pattern. The migration path to Events API is documented in *Future improvements*.

### 2. Workflow ID per Slack thread = session isolation

`workflow_id = f"slack-{team_id}-{channel_id}-{thread_ts}"`

Temporal guarantees workflow ID uniqueness within a namespace, so concurrent threads necessarily get distinct workflow executions. Each execution has its own history, its own activity retries, and its own state — there is no shared in-memory context between threads. A reviewer can verify isolation visually in the Temporal Web UI: two threads in flight produce two clickable workflow executions with no overlap.

`WorkflowIDReusePolicy.ALLOW_DUPLICATE` is set explicitly: each new message in a thread starts a fresh run under the same workflow ID. Both runs are visible in the UI grouped by workflow ID, so a reviewer can also see the per-thread history of agent invocations.

### 3. The agent runs **inside one activity**, not per-tool

Pydantic AI's tool loop runs the LLM repeatedly until the agent emits a final answer. Two reasonable shapes for this in Temporal:

- **Per-tool activities** — every LLM tool call becomes its own Temporal activity. Maximum durability, but requires inventing a way to suspend and resume Pydantic AI's loop across workflow turns.
- **One activity wraps the loop** — chosen here. The agent runs end-to-end inside `run_agent`, which heartbeats Temporal between LLM iterations.

Trade-off accepted: if the activity dies mid-loop, the next attempt re-runs from the user's prompt (idempotency provided by deterministic branch names). For a 2-day takehome this is the right shape; the per-tool approach is documented as future work.

### 4. Each Slack message = a new workflow run (not a long-lived workflow)

Each user message starts a new workflow execution under the thread's workflow ID. The workflow exits cleanly after one agent run. In-thread follow-ups produce new runs visible in the Temporal UI grouped by the same workflow ID — they don't carry conversational state into the agent.

The alternative (long-lived workflow with `wait_condition` on a signal + idle timer + `continue_as_new`) was scoped out:

- Adds ~80 LOC of signal/timer handling with subtle race conditions on signal-vs-completion.
- The simpler shape already gives session isolation, durable execution, and per-message recoverability — the load-bearing parts of Temporal's value here.
- Conversational continuity within a thread can be added later without restructuring; the current `WorkflowInput` already takes a single prompt and could grow to a list of messages.

### 5. Workflow sandbox disabled

`UnsandboxedWorkflowRunner` is used in `apps/temporal-worker/src/temporal_worker/main.py`. Pydantic AI's transitive deps (`beartype.claw` via `cyclopts`/`fastmcp`) install a process-wide import hook that triggers a circular import when Temporal's sandbox attempts a controlled re-import of the workflow module.

The workflow is deterministic by construction — every I/O call lives in an activity, the workflow body is a pair of `execute_activity` calls and a return — so the sandbox's safety check provides no real protection here. The cleaner long-term fix is to switch to `pydantic-ai-slim[google]` and re-enable the sandbox; documented in *Future improvements*.

### 6. Secrets via External Secrets Operator + AWS Secrets Manager

Slack tokens, the LLM API key, and the GitHub PAT live in AWS Secrets Manager. The External Secrets Operator runs in-cluster with an IRSA role (`tessera-eso`) granting `secretsmanager:GetSecretValue` on the four `tessera/*` secrets and on the RDS-managed master user secret.

`ClusterSecretStore aws-secrets-manager` is created once with the helm/temporal install. The two app charts each declare a small `ExternalSecret` that pulls the keys it needs into a Kubernetes Secret with the same name as the deployment, which the pod consumes via `envFrom`. The pod template carries a `checksum/secret` annotation that forces a rollout when secret content changes.

No secret value ever lives in git, in `helm template` output, or in container images. Terraform creates the Secrets Manager entries with placeholder values; the actual secrets are written out-of-band via the AWS console or `aws secretsmanager put-secret-value`.

### 7. RDS Postgres for Temporal persistence (not the in-cluster default)

A managed RDS Postgres instance backs Temporal — multi-AZ off (cost), encrypted at rest (gp3 + AES256), `manage_master_user_password = true` so the credential lives in Secrets Manager and rotates without Terraform touching it. SSL is enforced on the client side (Temporal Helm values set `tls.enabled: true` for both the default and visibility datastores), satisfying RDS's `rds.force_ssl=1` parameter.

Trade-off: provisioning is slower than an in-cluster StatefulSet. In return, the database survives node group rotation, takes EBS snapshots automatically, and lets Temporal scale node count without persistence migration.

### 8. Three-tier subnet design (public / private / data)

Public subnets (NAT gateways, future ALB), private subnets (EKS worker nodes), and data subnets (RDS only — no internet route). RDS lives in two data subnets across two AZs as required by AWS for any DB subnet group, even though the instance itself is single-AZ. The data subnets have no `0.0.0.0/0` route, so the database has no path to the internet — only intra-VPC reachability via the implicit `local` route. This was a deliberate design call to limit blast radius if the DB is ever compromised.

### 9. CI/CD via GitHub Actions OIDC → ECR

A GitHub OIDC provider is registered in AWS IAM. An IAM role (`tessera-gha-ecr-push`) trusts the provider with a `repo:ugoasoluka/tessera:*` subject condition. The build workflow assumes the role with no static AWS credentials in GitHub secrets. Daily versioning via `fregante/daily-version-action`; ECR repos are `IMMUTABLE` so re-pushing the same tag is a hard error.

### 10. Helm charts kept thin and identical in shape

Both app charts share the same skeleton: `Chart.yaml`, `values.yaml`, `_helpers.tpl`, `deployment.yaml`, `externalsecret.yaml`. No `Service` (both apps are outbound-only), no probes (no HTTP listener — restart-on-crash via container exit code is sufficient for these workloads), no `ServiceAccount` override (default SA is fine — neither pod talks to AWS APIs directly).

Pod and container security contexts pass restricted PodSecurity:
- `runAsNonRoot: true`, `runAsUser: 10001`
- `allowPrivilegeEscalation: false`
- `readOnlyRootFilesystem: true`
- `capabilities.drop: [ALL]`

---

## Privacy and session isolation

The assignment specifically calls out concurrent users with privacy and session isolation. The model:

- **Per-thread workflow ID.** Every Slack thread maps to exactly one workflow ID. Temporal enforces uniqueness; cross-thread state is impossible by construction.
- **Per-workflow branch name.** The agent operates on `agent/<sha1(workflow_id)[:10]>` — a deterministic, thread-scoped branch. Two threads cannot stomp on each other's commits or PRs.
- **No shared in-memory state.** The worker is stateless between activities. All inter-step state lives in workflow history (durable, encrypted at rest in RDS, scoped to the workflow execution).
- **Idempotent GitHub operations.** `ensure_branch` reuses an existing branch by name; `open_pr` returns the existing PR for a branch instead of opening a duplicate. Activity retries are safe.
- **Secrets never reach the agent.** The Pydantic AI agent receives the user prompt and the GitHub client; it does not get the raw PAT, Slack tokens, or the LLM API key — those are environment variables read by the activity wrapper and `httpx`/`PyGithub` clients.
- **Logging discipline.** Structlog JSON logs include workflow ID, thread ID, channel, user ID, and prompt length — never the prompt itself or model output. PR titles and bodies are emitted by the agent and posted as-is, which is acceptable because they are the user-visible result of the user's own request.
- **Network isolation.** RDS lives in data subnets with no internet route. EKS workers reach RDS through the worker security group, which is the only ingress allowed on the database SG. Cluster ↔ database traffic is TLS, encrypted in transit.

---

## Limitations

- **Workflow sandbox is disabled.** No automatic detection of accidental non-determinism in workflow code. Mitigated by keeping the workflow body trivially deterministic, but a future contributor could regress this.
- **Single org-level GitHub PAT.** The PAT has write access to one sandbox repo. A real deployment would use per-user GitHub App OAuth so PRs are attributed to the requesting human, and so the platform never holds long-lived org-write credentials.
- **No agent code execution sandbox.** The agent edits files via the GitHub API but never runs arbitrary shell commands or tests. If `bash` execution is added later, each invocation needs a per-task gVisor / Firecracker sandbox; currently we sidestep that whole class of risk by not having a code-execution tool at all.
- **`pydantic-ai` (full) is installed instead of `pydantic-ai-slim[google]`.** The full distribution pulls every provider's SDK (anthropic, openai, cohere, mistralai, groq, xai-sdk, mcp, fastmcp, logfire, otel) and ~100 MB of unused dependencies. This is the root cause of decision #5.
- **No Prometheus / Grafana / Loki.** Observability stack is `kubectl logs` plus the Temporal Web UI. Workflows are still inspectable in the UI with full step history.
- **No probes on app pods.** Both apps are outbound-only with no HTTP listener. Kubernetes restart-on-exit is the only liveness signal. A `/healthz` endpoint would be a small addition.
- **No PodDisruptionBudget, no HPA.** Single-replica deployments — fine at this traffic, would need both for production rollouts.
- **Helm charts not published.** Installed locally from the repo. Chart `version` stays at `0.1.0` since there's no consumer.
- **Single-AZ RDS.** `multi_az = false` to save cost. Failover is manual (snapshot → restore).
- **Trust policy on the GitHub OIDC role allows any ref.** `repo:ugoasoluka/tessera:*`. Production should scope this to `:ref:refs/heads/main` or to a GitHub Environment.

---

## Future improvements

In rough priority order if this work continued:

1. **Switch to `pydantic-ai-slim[google]`** and re-enable Temporal's workflow sandbox. Drops image size by ~3× and restores deterministic-import enforcement.
2. **Move conversational state into a long-lived workflow.** Replace per-message workflow runs with `signal_with_start` + `wait_condition(signal_received or idle_timeout)` + `continue_as_new` past ~50 turns. Makes follow-up Slack messages share LLM context naturally.
3. **Per-user GitHub App OAuth.** Replace the org-level PAT with a GitHub App; on first use, the bot DMs the user a link to grant repo access. PRs become attributable to humans.
4. **Per-tool activities** for the agent's tool loop. Trades implementation complexity for mid-loop durability — the agent can survive worker pod death between LLM turns instead of restarting from the prompt.
5. **Tighten the GitHub OIDC trust policy** to `:ref:refs/heads/main` or a GitHub Environment, so PR-builds can't push to ECR.
6. **Add a `/healthz` endpoint to both apps** with `aiohttp` + a Kubernetes liveness probe. Detects hung but not-crashed pods (e.g., a stuck WebSocket).
7. **Split task queues** — `tessera-coding-agent-fast` for quick agent runs, `tessera-coding-agent-slow` for long ones. Prevents one slow request from starving Slack acks.
8. **Multi-AZ RDS + automated backups + 7-day retention.** Currently `backup_retention_period = 0`, `multi_az = false` for cost.
9. **Observability stack.** Prometheus + Grafana for resource metrics, OpenTelemetry traces from Temporal/Pydantic AI through Logfire or Tempo. The dependencies are already installed; only the collector configuration is missing.
10. **Replace Slack Socket Mode with Events API.** Brings the bot into a publicly-reachable shape (ALB ingress + ACM + Route53), enables horizontally scaling the bot pod, supports OAuth-distributable installs.
11. **Network policies.** Default-deny east-west, then allow `slack-bot → temporal-frontend`, `temporal-worker → temporal-frontend`, both → kube-dns. Currently traffic inside the cluster is open by default.
12. **Code execution sandbox.** Add a `run_tests` tool to the agent backed by a per-invocation Kubernetes Job in a network-isolated, gVisor-runtimed namespace, so the agent can verify its changes before opening a PR.
