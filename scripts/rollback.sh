#!/usr/bin/env bash
# =============================================================================
# rollback.sh
# -----------------------------------------------------------------------------
# Automatic rollback triggered when the post-deploy health check fails.
# Reverts the Kubernetes Deployment to its previous revision and waits for
# the rollback itself to become healthy before exiting, so the pipeline
# never reports "rolled back" while pods are still crash-looping.
#
# Called from both jenkins/Jenkinsfile and .github/workflows/ci-cd.yml
# after health_check.sh reports a failure.
#
# Usage:
#   ./scripts/rollback.sh <namespace> <deployment-name>
# =============================================================================
set -euo pipefail

NAMESPACE="${1:?Usage: rollback.sh <namespace> <deployment-name>}"
DEPLOYMENT="${2:?Usage: rollback.sh <namespace> <deployment-name>}"

log() { echo "[rollback] $(date -u '+%Y-%m-%dT%H:%M:%SZ') - $*"; }

log "Rolling back deployment '${DEPLOYMENT}' in namespace '${NAMESPACE}'"

PREVIOUS_REVISION=$(kubectl rollout history deployment/"${DEPLOYMENT}" -n "${NAMESPACE}" \
  | tail -n 2 | head -n 1 | awk '{print $1}')

kubectl rollout undo deployment/"${DEPLOYMENT}" -n "${NAMESPACE}"

log "Waiting for rollback to stabilize..."
if kubectl rollout status deployment/"${DEPLOYMENT}" -n "${NAMESPACE}" --timeout=180s; then
  log "Rollback successful. '${DEPLOYMENT}' is back on revision ${PREVIOUS_REVISION:-previous}."
  exit 0
else
  log "ERROR: rollback did not stabilize within timeout. Manual intervention required."
  exit 1
fi
