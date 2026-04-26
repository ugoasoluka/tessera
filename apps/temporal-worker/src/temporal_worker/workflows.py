from __future__ import annotations

from datetime import timedelta

from temporalio import workflow
from temporalio.common import RetryPolicy

with workflow.unsafe.imports_passed_through():
    from .models import AgentResult, SlackPostInput, WorkflowInput


@workflow.defn(name="CodingAgentWorkflow")
class CodingAgentWorkflow:
    """One workflow per Slack thread.

    Steps:
        1. Run the agent on the user's prompt (one activity, internally
           drives the full LLM tool loop).
        2. Post the result back to the originating Slack thread.

    Workflow ID is set by the caller (slack-bot) from SlackContext, so two
    threads → two distinct executions, isolated histories, isolated retries.
    """

    @workflow.run
    async def run(self, input: WorkflowInput) -> AgentResult:
        workflow.logger.info(
            "workflow.start",
            extra={
                "workflow_id": workflow.info().workflow_id,
                "team_id": input.slack.team_id,
                "channel_id": input.slack.channel_id,
                "thread_ts": input.slack.thread_ts,
            },
        )

        # `result_type` is required when invoking activities by string name —
        # Temporal can't infer the Pydantic model from a string, so without
        # this the result comes back as a plain dict and `result.error` fails.
        agent_result: AgentResult = await workflow.execute_activity(
            "run_agent",
            input.prompt,
            result_type=AgentResult,
            start_to_close_timeout=timedelta(minutes=10),
            heartbeat_timeout=timedelta(minutes=2),
            retry_policy=RetryPolicy(
                maximum_attempts=1,  # agent failures are usually not retry-fixable
                non_retryable_error_types=["ValueError", "RuntimeError"],
            ),
        )

        reply_text = self._format_reply(agent_result)

        await workflow.execute_activity(
            "slack_post_thread_reply",
            SlackPostInput(
                channel_id=input.slack.channel_id,
                thread_ts=input.slack.thread_ts,
                text=reply_text,
            ),
            start_to_close_timeout=timedelta(seconds=30),
            retry_policy=RetryPolicy(
                initial_interval=timedelta(seconds=1),
                maximum_interval=timedelta(seconds=10),
                maximum_attempts=5,
            ),
        )

        return agent_result

    @staticmethod
    def _format_reply(result: AgentResult) -> str:
        if result.error:
            return f":warning: I ran into an error: {result.error}"
        if result.pr_url:
            return f":white_check_mark: {result.summary}\nPR: {result.pr_url}"
        return f":information_source: {result.summary}"