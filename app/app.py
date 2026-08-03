"""
Health-check service for the CI/CD pipeline's deploy stage.

The deploy stage polls /healthz after every rollout. If the app doesn't
report healthy within the configured timeout, the pipeline triggers
scripts/rollback.sh and scripts/slack_notify.py automatically (see
jenkins/Jenkinsfile and .github/workflows/ci-cd.yml).

/healthz    - liveness: is the process up at all
/ready      - readiness: are downstream dependencies reachable
/version    - build metadata injected at image build time
"""

import os
import time
from flask import Flask, jsonify

app = Flask(__name__)

START_TIME = time.time()

# Populated by --build-arg at image build time (see Dockerfile), falls back
# to "dev" so the service still runs fine outside a built image.
BUILD_VERSION = os.environ.get("BUILD_VERSION", "dev")
GIT_COMMIT = os.environ.get("GIT_COMMIT", "unknown")


def check_dependencies() -> dict:
    """
    Placeholder dependency checks. In a real deployment this would ping a
    database connection pool, a cache, or an upstream API. Kept dependency-
    free here so the health-check service itself never becomes the reason
    a deploy fails.
    """
    return {
        "database": "ok",
        "cache": "ok",
    }


@app.get("/healthz")
def healthz():
    """Liveness probe - process is up and can serve requests."""
    return jsonify(status="ok", uptime_seconds=round(time.time() - START_TIME, 2)), 200


@app.get("/ready")
def ready():
    """Readiness probe - safe to receive traffic."""
    checks = check_dependencies()
    healthy = all(v == "ok" for v in checks.values())
    status_code = 200 if healthy else 503
    return jsonify(status="ready" if healthy else "not_ready", checks=checks), status_code


@app.get("/version")
def version():
    return jsonify(version=BUILD_VERSION, commit=GIT_COMMIT), 200


@app.get("/")
def index():
    return jsonify(service="cicd-pipeline-healthcheck", status="running"), 200


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    app.run(host="0.0.0.0", port=port)
