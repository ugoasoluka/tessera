from __future__ import annotations

import asyncio
import logging
import signal
import sys

import structlog
from temporalio.client import Client
from temporalio.worker import Worker

from .activities import run_agent_activity, slack_post_thread_reply
from .config import Config
from .workflows import CodingAgentWorkflow


def _configure_logging() -> None:
    logging.basicConfig(
        format="%(message)s",
        stream=sys.stdout,
        level=logging.INFO,
    )
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


async def _run() -> None:
    log = structlog.get_logger(__name__)
    config = Config.from_env()

    log.info(
        "worker.connecting",
        address=config.temporal_address,
        namespace=config.temporal_namespace,
        task_queue=config.temporal_task_queue,
    )

    client = await Client.connect(
        config.temporal_address,
        namespace=config.temporal_namespace,
    )

    worker = Worker(
        client,
        task_queue=config.temporal_task_queue,
        workflows=[CodingAgentWorkflow],
        activities=[run_agent_activity, slack_post_thread_reply],
    )

    log.info("worker.started", task_queue=config.temporal_task_queue)

    # Graceful shutdown on SIGTERM (Kubernetes pod termination signal).
    stop_event = asyncio.Event()

    def _on_signal(*_args: object) -> None:
        log.info("worker.signal_received")
        stop_event.set()

    loop = asyncio.get_running_loop()
    for sig in (signal.SIGTERM, signal.SIGINT):
        loop.add_signal_handler(sig, _on_signal)

    async with worker:
        await stop_event.wait()

    log.info("worker.stopped")


def main() -> None:
    _configure_logging()
    asyncio.run(_run())


if __name__ == "__main__":
    main()