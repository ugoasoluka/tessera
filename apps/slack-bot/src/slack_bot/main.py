from __future__ import annotations

import asyncio
import logging
import re
import signal
import sys

import structlog
from slack_bolt.adapter.socket_mode.async_handler import AsyncSocketModeHandler
from slack_bolt.async_app import AsyncApp

from .config import Config
from .models import SlackContext, WorkflowInput
from .temporal_client import TemporalClient


def _configure_logging() -> None:
    logging.basicConfig(format="%(message)s", stream=sys.stdout, level=logging.INFO)
    structlog.configure(
        processors=[
            structlog.processors.add_log_level,
            structlog.processors.TimeStamper(fmt="iso"),
            structlog.processors.StackInfoRenderer(),
            structlog.processors.format_exc_info,
            structlog.processors.JSONRenderer(),
        ],
        wrapper_class=structlog.make_filtering_bound_logger(logging.INFO),
        cache_logger_on_first_use=True,
    )


_MENTION_RE = re.compile(r"<@[A-Z0-9]+>\s*")


def _strip_mention(text: str) -> str:
    """Remove the leading <@BOTID> from an app_mention message."""
    return _MENTION_RE.sub("", text, count=1).strip()


def _build_app(temporal: TemporalClient) -> AsyncApp:
    log = structlog.get_logger(__name__)
    config = Config.from_env()
    app = AsyncApp(token=config.slack_bot_token)

    @app.event("app_mention")
    async def on_app_mention(event: dict, body: dict, say) -> None:
        prompt = _strip_mention(event.get("text", ""))
        thread_ts = event.get("thread_ts") or event["ts"]
        team_id = body.get("team_id", "unknown")

        slack_ctx = SlackContext(
            team_id=team_id,
            channel_id=event["channel"],
            thread_ts=thread_ts,
            user_id=event["user"],
        )

        log.info(
            "app_mention.received",
            channel=slack_ctx.channel_id,
            thread_ts=slack_ctx.thread_ts,
            user=slack_ctx.user_id,
            prompt_len=len(prompt),
        )

        if not prompt:
            await say(
                channel=slack_ctx.channel_id,
                thread_ts=slack_ctx.thread_ts,
                text=":thinking_face: I didn't catch a request. Mention me with what you'd like me to do.",
            )
            return

        await say(
            channel=slack_ctx.channel_id,
            thread_ts=slack_ctx.thread_ts,
            text=":hammer_and_wrench: On it. I'll reply here when I'm done.",
        )

        try:
            run_id = await temporal.start_coding_agent(
                WorkflowInput(prompt=prompt, slack=slack_ctx)
            )
            log.info("workflow.started", run_id=run_id)
        except Exception:
            log.exception("workflow.start_failed")
            await say(
                channel=slack_ctx.channel_id,
                thread_ts=slack_ctx.thread_ts,
                text=":warning: I couldn't start a run. Check the bot logs.",
            )

    @app.event("message")
    async def on_message(event: dict) -> None:
        # Bolt requires a handler for subscribed events; we only act on mentions.
        return

    return app


async def _run() -> None:
    log = structlog.get_logger(__name__)
    config = Config.from_env()

    temporal = await TemporalClient.connect(config)
    app = _build_app(temporal)

    handler = AsyncSocketModeHandler(app, config.slack_app_token)

    # Graceful shutdown so Kubernetes pod evictions don't drop in-flight events.
    stop_event = asyncio.Event()

    def _on_signal(*_args: object) -> None:
        log.info("bot.signal_received")
        stop_event.set()

    loop = asyncio.get_running_loop()
    for sig in (signal.SIGTERM, signal.SIGINT):
        loop.add_signal_handler(sig, _on_signal)

    log.info("bot.starting")
    await handler.start_async()
    log.info("bot.started")

    await stop_event.wait()

    log.info("bot.stopping")
    await handler.close_async()
    log.info("bot.stopped")


def main() -> None:
    _configure_logging()
    asyncio.run(_run())


if __name__ == "__main__":
    main()