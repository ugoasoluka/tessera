# Tessera Coding Agent Platform

A Slack-based coding assistant that orchestrates LLM-driven code changes through durable Temporal workflows and integrates with GitHub.

## Architecture at a glance
User → Slack → EKS (Temporal + Pydantic AI worker) → GitHub PR

Slack receives a message, the bot starts a Temporal workflow, the workflow drives a Pydantic AI agent that proposes code changes, and a PR is opened on GitHub. Temporal makes the whole thing durable across pod and node failures. Each Slack thread maps to one workflow ID for session isolation.

See [`DESIGN.md`](./DESIGN.md) for decisions, trade-offs, and future improvements.

## Repository layout

kubectl exec -n temporal deployment/tessera-temporal-admintools -- \
  temporal operator namespace create \
    --namespace tessera \
    --retention 7d \
    --address tessera-temporal-frontend:7233