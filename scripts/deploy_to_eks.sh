#!/usr/bin/env bash
# =============================================================================
# deploy_to_eks.sh
# -----------------------------------------------------------------------------
# Shared deploy step called by both the Jenkins and GitHub Actions
# pipelines, kept in one place so the two pipelines can never drift apart
# on how a deploy actually happens.
#
# Usage:
#   ./scripts/deploy_to_eks.sh <cluster-name> <namespace> <image-uri>
# =============================================================================
set -euo pipefail

CLUSTER_NAME="${1:?Usage: deploy_to_eks.sh <cluster-name> <namespace> <image-uri>}"
NAMESPACE="${2:?Usage: deploy_to_eks.sh <cluster-name> <namespace> <image-uri>}"
IMAGE_URI="${3:?Usage: deploy_to_eks.sh <cluster-name> <namespace> <image-uri>}"
REGION="${AWS_REGION:-us-east-1}"
DEPLOYMENT_NAME="healthcheck"

log() { echo "[deploy] $(date -u '+%Y-%m-%dT%H:%M:%SZ') - $*"; }

log "Authenticating to cluster ${CLUSTER_NAME}"
aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region "${REGION}"

log "Deploying image ${IMAGE_URI} to ${NAMESPACE}/${DEPLOYMENT_NAME}"
kubectl set image deployment/"${DEPLOYMENT_NAME}" "${DEPLOYMENT_NAME}=${IMAGE_URI}" \
  -n "${NAMESPACE}" --record

kubectl rollout status deployment/"${DEPLOYMENT_NAME}" -n "${NAMESPACE}" --timeout=180s

log "Deploy complete."
