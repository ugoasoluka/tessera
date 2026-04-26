from __future__ import annotations

import structlog
from temporalio.client import Client
from temporalio.common import WorkflowIDReusePolicy
from .config import Config
from .models import WorkflowInput, workflow_id_from_slack

log = structlog.get_logger(__name__)


class TemporalClient:
    """Wraps a Temporal Client with a single method to start the agent workflow."""

    def __init__(self, client: Client, config: Config) -> None:
        self._client = client
        self._config = config

    @classmethod
    async def connect(cls, config: Config) -> "TemporalClient":
        log.info(
            "temporal.connecting",
            address=config.temporal_address,
            namespace=config.temporal_namespace,
        )
        client = await Client.connect(
            config.temporal_address,
            namespace=config.temporal_namespace,
        )
        log.info("temporal.connected")
        return cls(client=client, config=config)

    async def start_coding_agent(self, input: WorkflowInput) -> str:
        """Start (or get an existing) CodingAgentWorkflow run for this Slack thread.

        Returns the workflow's run_id. Same Slack thread → same workflow_id;
        ALLOW_DUPLICATE policy means each new message starts a fresh run.
        """
        workflow_id = workflow_id_from_slack(input.slack)

        handle = await self._client.start_workflow(
            "CodingAgentWorkflow",
            input,
            id=workflow_id,
            task_queue=self._config.temporal_task_queue,
            id_reuse_policy=WorkflowIDReusePolicy.ALLOW_DUPLICATE,
        )

        log.info(
            "workflow.started",
            workflow_id=workflow_id,
            run_id=handle.result_run_id,
        )
        return handle.result_run_id