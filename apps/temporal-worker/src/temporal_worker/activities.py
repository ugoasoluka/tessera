from __future__ import annotations

import structlog
from temporalio import activity

from .agent import run_agent
from .config import Config
from .github import GitHubClient
from .models import AgentResult, SlackPostInput
from .slack import SlackClient, SlackPost

log = structlog.get_logger(__name__)


@activity.defn(name="run_agent")
async def run_agent_activity(prompt: str) -> AgentResult:
    """Run the Pydantic AI agent end-to-end inside one activity.

    Heartbeats between LLM turns so a stuck agent gets cancelled by Temporal
    instead of hanging until activity timeout.
    """
    info = activity.info()
    log.info(
        "agent_activity.start",
        workflow_id=info.workflow_id,
        attempt=info.attempt,
        prompt_len=len(prompt),
    )

    config = Config.from_env()
    github = GitHubClient(token=config.github_token, repo_full_name=config.github_repo)

    def on_iteration() -> None:
        # Called between every agent turn. Tells Temporal "I'm alive."
        activity.heartbeat({"workflow_id": info.workflow_id, "attempt": info.attempt})

    try:
        summary, pr_url = await run_agent(
            model=config.llm_model,
            prompt=prompt,
            github=github,
            workflow_id=info.workflow_id,
            on_iteration=on_iteration,
        )
    except Exception as exc:
        log.exception("agent_activity.failed", workflow_id=info.workflow_id)
        return AgentResult(
            summary="Agent run failed.",
            pr_url=None,
            error=str(exc),
        )

    log.info(
        "agent_activity.done",
        workflow_id=info.workflow_id,
        pr_url=pr_url,
        summary_len=len(summary),
    )
    return AgentResult(summary=summary, pr_url=pr_url, error=None)


@activity.defn(name="slack_post_thread_reply")
async def slack_post_thread_reply(payload: SlackPostInput) -> str:
    """Post a single message to a Slack thread. Returns the new message's ts."""
    config = Config.from_env()
    client = SlackClient(bot_token=config.slack_bot_token)
    post = SlackPost(
        channel_id=payload.channel_id,
        thread_ts=payload.thread_ts,
        text=payload.text,
    )
    log.info(
        "slack_post.start",
        channel=payload.channel_id,
        thread_ts=payload.thread_ts,
        text_len=len(payload.text),
    )
    new_ts = client.post_thread_reply(post)
    log.info("slack_post.done", new_ts=new_ts)
    return new_ts