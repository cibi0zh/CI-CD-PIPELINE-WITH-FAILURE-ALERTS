#!/usr/bin/env python3
"""
slack_notify.py
-----------------
Sends a pipeline status message to Slack via an incoming webhook. Used at
the end of both the Jenkins and GitHub Actions pipelines to report success,
and specifically on deploy failure to alert on-call before/alongside the
automatic rollback triggered by rollback.sh.

The webhook URL is never hardcoded - it's read from SLACK_WEBHOOK_URL,
injected as a CI secret (GitHub Actions secret / Jenkins credential),
never committed to this repo.

Usage:
    python slack_notify.py --status failure --stage deploy \
        --message "Deploy to eks-dev failed health checks, rolling back" \
        --build-url "$BUILD_URL"
"""

import argparse
import json
import os
import sys
import urllib.request

STATUS_COLORS = {
    "success": "#2eb886",
    "failure": "#e01e5a",
    "warning": "#ecb22e",
    "info": "#439fe0",
}


def build_payload(status: str, stage: str, message: str, build_url: str, channel: str) -> dict:
    color = STATUS_COLORS.get(status, "#439fe0")
    fields = [
        {"title": "Stage", "value": stage, "short": True},
        {"title": "Status", "value": status.upper(), "short": True},
    ]
    if build_url:
        fields.append({"title": "Build", "value": build_url, "short": False})

    return {
        "channel": channel,
        "attachments": [
            {
                "color": color,
                "title": "CI/CD Pipeline Notification",
                "text": message,
                "fields": fields,
            }
        ],
    }


def send(webhook_url: str, payload: dict, timeout: int = 10) -> None:
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        webhook_url,
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        if resp.status >= 300:
            raise RuntimeError(f"Slack webhook returned status {resp.status}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Post a pipeline status message to Slack")
    parser.add_argument("--status", choices=list(STATUS_COLORS), default="info")
    parser.add_argument("--stage", required=True, help="Pipeline stage, e.g. build/test/scan/deploy")
    parser.add_argument("--message", required=True)
    parser.add_argument("--build-url", default="")
    parser.add_argument("--channel", default="#platform-alerts")
    args = parser.parse_args()

    webhook_url = os.environ.get("SLACK_WEBHOOK_URL")
    if not webhook_url:
        print("[slack_notify] SLACK_WEBHOOK_URL not set, skipping notification.", file=sys.stderr)
        # Don't fail the pipeline just because alerting isn't configured yet.
        return 0

    payload = build_payload(args.status, args.stage, args.message, args.build_url, args.channel)

    try:
        send(webhook_url, payload)
    except Exception as exc:  # noqa: BLE001 - alerting must never crash the pipeline
        print(f"[slack_notify] Failed to send Slack notification: {exc}", file=sys.stderr)
        return 0

    print(f"[slack_notify] Sent {args.status} notification for stage '{args.stage}'.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
