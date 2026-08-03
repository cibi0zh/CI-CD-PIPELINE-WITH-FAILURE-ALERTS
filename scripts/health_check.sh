#!/usr/bin/env bash
# =============================================================================
# health_check.sh
# -----------------------------------------------------------------------------
# Polls the deployed service's /healthz and /ready endpoints after a
# rollout. Exits non-zero if the service doesn't report healthy within the
# timeout, which the calling pipeline treats as a signal to run rollback.sh.
#
# Usage:
#   ./scripts/health_check.sh https://api.example.com 120
# =============================================================================
set -euo pipefail

TARGET_URL="${1:?Usage: health_check.sh <base-url> [timeout-seconds]}"
TIMEOUT_SECONDS="${2:-120}"
INTERVAL_SECONDS=5

log() { echo "[health_check] $(date -u '+%Y-%m-%dT%H:%M:%SZ') - $*"; }

elapsed=0
while [ "${elapsed}" -lt "${TIMEOUT_SECONDS}" ]; do
  if curl -fsS --max-time 5 "${TARGET_URL}/healthz" > /dev/null 2>&1 \
     && curl -fsS --max-time 5 "${TARGET_URL}/ready" > /dev/null 2>&1; then
    log "Service at ${TARGET_URL} is healthy and ready."
    exit 0
  fi
  log "Not healthy yet (${elapsed}s/${TIMEOUT_SECONDS}s elapsed), retrying in ${INTERVAL_SECONDS}s..."
  sleep "${INTERVAL_SECONDS}"
  elapsed=$((elapsed + INTERVAL_SECONDS))
done

log "ERROR: ${TARGET_URL} did not become healthy within ${TIMEOUT_SECONDS}s."
exit 1
