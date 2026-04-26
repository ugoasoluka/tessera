from __future__ import annotations

from pydantic import BaseModel, Field


class SlackContext(BaseModel):
    """Identifying info about a Slack message that anchors a workflow run."""

    team_id: str = Field(..., description="Slack workspace ID, e.g. T0123ABCD")
    channel_id: str = Field(..., description="Slack channel ID, e.g. C0456EFGH")
    thread_ts: str = Field(
        ...,
        description="Thread timestamp; for top-level messages this is the message's own ts",
    )
    user_id: str = Field(..., description="Slack user ID who sent the message")


class WorkflowInput(BaseModel):
    """Payload for CodingAgentWorkflow."""

    prompt: str = Field(..., description="The user's natural-language request")
    slack: SlackContext


class AgentResult(BaseModel):
    """What the agent activity returns to the workflow."""

    summary: str = Field(..., description="Short human-readable summary of what the agent did")
    pr_url: str | None = Field(
        default=None,
        description="URL of the GitHub PR if one was opened, else None",
    )
    error: str | None = Field(
        default=None,
        description="Error message if the agent failed; None on success",
    )

    @property
    def succeeded(self) -> bool:
        return self.error is None


class SlackPostInput(BaseModel):
    """Payload for the slack_post_thread_reply activity."""

    channel_id: str
    thread_ts: str
    text: str


def workflow_id_from_slack(ctx: SlackContext) -> str:
    """Deterministic workflow ID derived from Slack context.

    One workflow per (workspace, channel, thread). Same thread → same ID,
    which lets us either signal an existing run or reject a duplicate.
    """
    return f"slack-{ctx.team_id}-{ctx.channel_id}-{ctx.thread_ts}"