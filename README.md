# Secure CI/CD & GitOps Automation Pipeline

Jenkins and GitHub Actions pipelines that build, test, scan, containerize,
and deploy a Flask health-check service to EKS, with keyless AWS auth,
required security scans, and automatic rollback on failed deploys.

This repo is the CI/CD layer for the platform provisioned in
[Enterprise-Cloud-Infrastructure-Kubernetes-Platform-AWS](https://github.com/cibi0zh/Enterprise-Cloud-Infrastructure-Kubernetes-Platform-AWS-) -
that repo owns the EKS cluster and VPC; this one owns getting code onto it
safely.

**Stack:** Jenkins · GitHub Actions · Terraform · Docker · AWS EKS/ECR ·
OIDC · Trivy · tfsec · Python (Flask, Pytest)

## What's in here

- Jenkins and GitHub Actions pipelines that run the same five stages -
  build, test, scan, containerize, deploy - with staged manual approval
  before production.
- OpenID Connect (OIDC) federation replacing static AWS access keys for
  both pipelines, so there's no long-lived credential to leak or rotate.
- Trivy (container image) and tfsec (Terraform) scans wired in as required
  checks that block merges on critical findings.
- A small Flask + Pytest health-check service, with automatic rollback and
  Slack alerting if a deploy fails its post-deploy health check.

## Repository structure

```
.
├── app/                    # Flask health-check service + pytest suite
│   ├── app.py
│   ├── tests/
│   └── Dockerfile
├── jenkins/
│   ├── Jenkinsfile          # Declarative pipeline: build/test/scan/deploy
│   └── scripts/              # Agent tooling bootstrap
├── .github/workflows/
│   ├── ci-cd.yml              # Main pipeline (mirrors the Jenkinsfile)
│   ├── terraform-plan.yml     # Plan/validate on infra PRs
│   └── codeql.yml              # Static analysis for the Python app
├── terraform/
│   ├── oidc/                  # GitHub Actions + Jenkins OIDC federation
│   └── ecr/                    # Container registry, scan-on-push
├── scripts/                  # Shared by both pipelines
│   ├── deploy_to_eks.sh
│   ├── health_check.sh
│   ├── rollback.sh
│   └── slack_notify.py
├── .trivy.yaml / .trivyignore   # Trivy scan config
├── .tfsec.yml                    # tfsec scan config
└── docs/
    ├── PIPELINE.md              # Stage-by-stage walkthrough
    └── OIDC_SETUP.md              # Why/how OIDC replaced static keys
```

## Quick start

```bash
# 1. Provision the OIDC roles and ECR repo
cd terraform
cp terraform.tfvars.example terraform.tfvars   # fill in cluster/state ARNs
terraform init
terraform apply

# 2. Wire secrets into GitHub
#    Settings > Secrets and variables > Actions:
#      AWS_GHA_ROLE_ARN   = output "github_actions_role_arn" from step 1
#      SLACK_WEBHOOK_URL  = your incoming webhook URL

# 3. Configure branch protection on main:
#    require the build-and-test, tfsec, and build-and-scan-image checks

# 4. Push to main - the pipeline builds, tests, scans, deploys to dev
#    automatically, then waits for approval before deploying to prod.
```

See [`docs/PIPELINE.md`](docs/PIPELINE.md) for the full stage-by-stage
breakdown and [`docs/OIDC_SETUP.md`](docs/OIDC_SETUP.md) for how the
keyless AWS auth is wired up end to end.

## Local development

```bash
cd app
pip install -r requirements-dev.txt
pytest

# or run the container locally
docker compose up --build
curl localhost:8080/healthz
```

## License

MIT - see [LICENSE](LICENSE).
