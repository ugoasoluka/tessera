from __future__ import annotations

from dataclasses import dataclass

from slack_sdk import WebClient
from slack_sdk.errors import SlackApiError


@dataclass(frozen=True)
class SlackPost:
    channel_id: str
    thread_ts: str
    text: str


class SlackClient:
    """Thin wrapper around slack_sdk.WebClient for thread replies."""

    def __init__(self, bot_token: str) -> None:
        self._client = WebClient(token=bot_token)

    def post_thread_reply(self, post: SlackPost) -> str:
        """Post a message to a Slack thread. Returns the new message's ts."""
        try:
            response = self._client.chat_postMessage(
                channel=post.channel_id,
                thread_ts=post.thread_ts,
                text=post.text,
            )
        except SlackApiError as e:
            raise RuntimeError(f"Slack API error: {e.response.get('error', 'unknown')}") from e

        if not response.get("ok"):
            raise RuntimeError(f"Slack returned not-ok: {response.get('error', 'unknown')}")

        return response["ts"]