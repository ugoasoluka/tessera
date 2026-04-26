from __future__ import annotations

from pydantic import BaseModel, Field


class SlackContext(BaseModel):
    team_id: str
    channel_id: str
    thread_ts: str
    user_id: str


class WorkflowInput(BaseModel):
    prompt: str = Field(..., description="The user's natural-language request")
    slack: SlackContext


def workflow_id_from_slack(ctx: SlackContext) -> str:
    """Deterministic workflow ID derived from Slack context. Must match worker."""
    return f"slack-{ctx.team_id}-{ctx.channel_id}-{ctx.thread_ts}"