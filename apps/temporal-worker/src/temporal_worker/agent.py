from __future__ import annotations

from dataclasses import dataclass
from typing import Callable

from pydantic_ai import Agent, RunContext

from .github import FileChange, GitHubClient, PullRequestResult


SYSTEM_PROMPT = """\
You are a careful, focused coding agent operating on a single Git repository.

You receive a request from a user via Slack. Your job:
1. Understand what they want.
2. Read relevant files in the repository to ground your changes in the existing code.
3. Make the smallest set of file changes that fulfill the request.
4. Open a single pull request describing what you did and why.

Rules:
- Always inspect the repo (list files, read existing files) before writing.
- Prefer additive changes over destructive ones.
- If a request is ambiguous or destructive (e.g. delete files, mass-rewrite), ask for confirmation by returning a clarifying question instead of acting. (For this demo, treat clarification as a final answer with no PR.)
- Never include secrets, API keys, or credentials in any file you write.
- Keep PR titles concise (<72 chars). Keep PR bodies focused: what, why, and what you didn't do.
- When you've finished writing files, call open_pull_request exactly once.

You operate on a fixed repository configured by the platform. You cannot
choose a different repository.
"""


@dataclass
class AgentDeps:
    """Runtime dependencies threaded into every tool call via RunContext."""

    github: GitHubClient
    workflow_id: str
    branch: str  # the branch this run will commit to (deterministic from workflow_id)
    pr_result: dict  # mutable handle so tools can record the PR they opened


def build_agent(model: str) -> Agent[AgentDeps, str]:
    """Construct the Pydantic AI agent.

    Returns an Agent whose final result is a string summary of what was done.
    """
    agent: Agent[AgentDeps, str] = Agent(
            model=model,
            deps_type=AgentDeps,
            output_type=str,
            system_prompt=SYSTEM_PROMPT,
            instrument=True,
        )

    @agent.tool
    async def list_repo_files(ctx: RunContext[AgentDeps], path: str = "") -> list[str]:
        """List file paths in the repository, optionally filtered by a path prefix."""
        return ctx.deps.github.list_files(path=path)

    @agent.tool
    async def read_file(ctx: RunContext[AgentDeps], path: str) -> str:
        """Read the content of a file from the default branch.

        Returns empty string if the file does not exist (use this to check
        before creating a new file).
        """
        return ctx.deps.github.read_file(path=path)

    @agent.tool
    async def write_file(
        ctx: RunContext[AgentDeps],
        path: str,
        content: str,
        message: str,
    ) -> str:
        """Create or update a file on the agent's working branch.

        Args:
            path: Repo-relative file path, e.g. 'docs/CONTRIBUTING.md'.
            content: Full file content (not a diff).
            message: Commit message for this change.

        Returns a confirmation string. Failures raise.
        """
        ctx.deps.github.ensure_branch(ctx.deps.branch)
        ctx.deps.github.write_file(
            branch=ctx.deps.branch,
            change=FileChange(path=path, content=content, message=message),
        )
        return f"Wrote {path} on branch {ctx.deps.branch}"

    @agent.tool
    async def open_pull_request(
        ctx: RunContext[AgentDeps],
        title: str,
        body: str,
    ) -> str:
        """Open a pull request from the working branch to the default branch.

        Call this exactly once when you have finished making file changes.
        Returns the PR URL.
        """
        result: PullRequestResult = ctx.deps.github.open_pr(
            branch=ctx.deps.branch,
            title=title,
            body=body,
        )
        ctx.deps.pr_result["url"] = result.url
        ctx.deps.pr_result["number"] = result.number
        return f"Opened PR #{result.number}: {result.url}"

    return agent


async def run_agent(
    *,
    model: str,
    prompt: str,
    github: GitHubClient,
    workflow_id: str,
    on_iteration: Callable[[], None] | None = None,    
) -> tuple[str, str | None]:
    """Run the agent end-to-end and return (summary, pr_url_or_none).

    `on_iteration` is called between LLM turns; the activity uses it to send
    Temporal heartbeats so a stuck agent gets cancelled instead of hanging.
    """
    branch = github.branch_name_for_workflow(workflow_id)
    pr_result: dict = {}
    deps = AgentDeps(
        github=github,
        workflow_id=workflow_id,
        branch=branch,
        pr_result=pr_result,
    )

    agent = build_agent(model)

    # Pydantic AI's `iter` API exposes the agent's loop, letting us heartbeat
    # between turns rather than running it as one opaque awaitable.
    async with agent.iter(prompt, deps=deps) as run:
        async for _node in run:
            if on_iteration is not None:
                on_iteration()
        result = run.result

    summary = result.output if result and result.output else "Agent finished without a summary."
    pr_url = pr_result.get("url")
    return summary, pr_url