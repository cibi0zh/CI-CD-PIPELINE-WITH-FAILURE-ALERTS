#!/usr/bin/env bash
# =============================================================================
# install_agent_tools.sh
# -----------------------------------------------------------------------------
# One-time setup for a Jenkins agent host: installs the CLIs the Jenkinsfile
# shells out to (docker, aws cli, kubectl, trivy, tfsec). Run once when
# provisioning a new agent, or via the agent's own bootstrap/user-data.
# =============================================================================
set -euo pipefail

log() { echo "[install_agent_tools] $*"; }

# AWS CLI v2
if ! command -v aws >/dev/null 2>&1; then
  log "Installing AWS CLI v2"
  curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
  unzip -q /tmp/awscliv2.zip -d /tmp
  sudo /tmp/aws/install
fi

# kubectl
if ! command -v kubectl >/dev/null 2>&1; then
  log "Installing kubectl"
  KUBECTL_VERSION="v1.30.0"
  curl -sSL -o /tmp/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
  chmod +x /tmp/kubectl
  sudo mv /tmp/kubectl /usr/local/bin/kubectl
fi

# Trivy
if ! command -v trivy >/dev/null 2>&1; then
  log "Installing Trivy"
  curl -sSL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
    | sudo sh -s -- -b /usr/local/bin
fi

# tfsec
if ! command -v tfsec >/dev/null 2>&1; then
  log "Installing tfsec"
  curl -sSL https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh \
    | sudo sh
fi

log "Verifying installed tool versions:"
aws --version
kubectl version --client
trivy --version
tfsec --version

log "Jenkins agent tooling ready."
