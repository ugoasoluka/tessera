from __future__ import annotations

import base64
import hashlib
from dataclasses import dataclass

from github import Auth, Github
from github.GithubException import GithubException


@dataclass(frozen=True)
class FileChange:
    """A single file change the agent wants to make."""

    path: str
    content: str
    message: str  # commit message for this change


@dataclass(frozen=True)
class PullRequestResult:
    url: str
    number: int
    branch: str


class GitHubClient:
    """Thin wrapper around PyGithub scoped to a single repo.

    Idempotency strategy: branch names are derived deterministically from a
    workflow_id. If a branch already exists from a prior attempt, we reuse it
    and append commits. If a PR already exists for the branch, we return its
    URL instead of opening a duplicate.
    """

    def __init__(self, token: str, repo_full_name: str) -> None:
        self._client = Github(auth=Auth.Token(token))
        self._repo = self._client.get_repo(repo_full_name)

    def read_file(self, path: str, ref: str | None = None) -> str:
        """Read a file's content from the repo. Returns empty string if missing."""
        try:
            ref = ref or self._repo.default_branch
            contents = self._repo.get_contents(path, ref=ref)
            if isinstance(contents, list):
                raise ValueError(f"{path} is a directory, not a file")
            return base64.b64decode(contents.content).decode("utf-8")
        except GithubException as e:
            if e.status == 404:
                return ""
            raise

    def list_files(self, path: str = "", ref: str | None = None) -> list[str]:
        """List files (recursively) under a path. Used to give the agent context."""
        ref = ref or self._repo.default_branch
        try:
            tree = self._repo.get_git_tree(ref, recursive=True)
        except GithubException:
            return []
        return [
            item.path
            for item in tree.tree
            if item.type == "blob" and item.path.startswith(path)
        ]

    def branch_name_for_workflow(self, workflow_id: str) -> str:
        """Deterministic branch name from the workflow ID.

        Slack workflow IDs are like 'slack-T123-C456-1234567890.123456' which
        contains a '.' — git allows it, but we hash for a tidy short name.
        """
        digest = hashlib.sha1(workflow_id.encode()).hexdigest()[:10]
        return f"agent/{digest}"

    def ensure_branch(self, branch: str, base: str | None = None) -> None:
        """Create the branch off `base` if it doesn't exist. Idempotent."""
        base = base or self._repo.default_branch
        try:
            self._repo.get_branch(branch)
            return  # already exists
        except GithubException as e:
            if e.status != 404:
                raise

        base_ref = self._repo.get_branch(base)
        self._repo.create_git_ref(ref=f"refs/heads/{branch}", sha=base_ref.commit.sha)

    def write_file(self, branch: str, change: FileChange) -> None:
        """Create or update a file on `branch`."""
        try:
            existing = self._repo.get_contents(change.path, ref=branch)
            if isinstance(existing, list):
                raise ValueError(f"{change.path} is a directory")
            self._repo.update_file(
                path=change.path,
                message=change.message,
                content=change.content,
                sha=existing.sha,
                branch=branch,
            )
        except GithubException as e:
            if e.status != 404:
                raise
            # File doesn't exist; create it.
            self._repo.create_file(
                path=change.path,
                message=change.message,
                content=change.content,
                branch=branch,
            )

    def open_pr(
        self,
        branch: str,
        title: str,
        body: str,
        base: str | None = None,
    ) -> PullRequestResult:
        """Open a PR from `branch` to `base`. Returns existing PR if one is open."""
        base = base or self._repo.default_branch

        # Check for an existing open PR from this branch — idempotency.
        existing = list(
            self._repo.get_pulls(
                state="open",
                head=f"{self._repo.owner.login}:{branch}",
                base=base,
            )
        )
        if existing:
            pr = existing[0]
            return PullRequestResult(url=pr.html_url, number=pr.number, branch=branch)

        pr = self._repo.create_pull(title=title, body=body, head=branch, base=base)
        return PullRequestResult(url=pr.html_url, number=pr.number, branch=branch)