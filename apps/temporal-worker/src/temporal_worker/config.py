from __future__ import annotations

import os
from dataclasses import dataclass


def _required(name: str) -> str:
    value = os.environ.get(name)
    if not value:
        raise RuntimeError(f"Required environment variable {name} is not set")
    return value


@dataclass(frozen=True)
class Config:
    # Temporal
    temporal_address: str
    temporal_namespace: str
    temporal_task_queue: str

    # GitHub
    github_token: str
    github_repo: str  # "owner/repo"

    # Slack
    slack_bot_token: str

    # LLM (Gemini, despite the env var name)
    llm_api_key: str
    llm_model: str

    # Workflow / activity tuning
    agent_activity_timeout_seconds: int

    @classmethod
    def from_env(cls) -> "Config":
        return cls(
            temporal_address=os.environ.get(
                "TEMPORAL_ADDRESS", "tessera-temporal-frontend.temporal.svc.cluster.local:7233"
            ),
            temporal_namespace=os.environ.get("TEMPORAL_NAMESPACE", "tessera"),
            temporal_task_queue=os.environ.get("TEMPORAL_TASK_QUEUE", "tessera-coding-agent"),
            github_token=_required("GITHUB_TOKEN"),
            github_repo=_required("GITHUB_REPO"),
            slack_bot_token=_required("SLACK_BOT_TOKEN"),
            llm_api_key=_required("LLM_API_KEY"),
            llm_model=os.environ.get("LLM_MODEL", "google-gla:gemini-2.0-flash"),
            agent_activity_timeout_seconds=int(
                os.environ.get("AGENT_ACTIVITY_TIMEOUT_SECONDS", "600")
            ),
        )