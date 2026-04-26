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
    # Slack
    slack_bot_token: str  # xoxb-...
    slack_app_token: str  # xapp-... (Socket Mode)

    # Temporal
    temporal_address: str
    temporal_namespace: str
    temporal_task_queue: str

    @classmethod
    def from_env(cls) -> "Config":
        return cls(
            slack_bot_token=_required("SLACK_BOT_TOKEN"),
            slack_app_token=_required("SLACK_APP_TOKEN"),
            temporal_address=os.environ.get(
                "TEMPORAL_ADDRESS",
                "tessera-temporal-frontend.temporal.svc.cluster.local:7233",
            ),
            temporal_namespace=os.environ.get("TEMPORAL_NAMESPACE", "tessera"),
            temporal_task_queue=os.environ.get("TEMPORAL_TASK_QUEUE", "tessera-coding-agent"),
        )