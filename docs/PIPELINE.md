# Pipeline Walkthrough

Both the Jenkins and GitHub Actions pipelines implement the same five
stages, in the same order, calling the same shared scripts under
`scripts/` so the two never drift apart on what "deploy" actually means.

## Stages

1. **Build** - install the Flask app's dependencies (`app/requirements-dev.txt`).
2. **Test** - run the Pytest suite (`app/tests/`), publish JUnit results.
3. **Scan**
   - **Trivy** scans the built container image for CRITICAL/HIGH
     vulnerabilities (`.trivy.yaml`). Any hit fails the build.
   - **tfsec** scans `terraform/` for insecure IaC patterns (`.tfsec.yml`).
     Any MEDIUM+ finding fails the build.
   - Both are configured as required status checks - a PR cannot merge
     to `main` while either is red.
4. **Containerize** - build the image, tag it with the short git SHA, push
   to ECR. GitHub Actions authenticates via OIDC
   (`aws-actions/configure-aws-credentials` assuming the role from
   `terraform/oidc`); Jenkins authenticates via its EC2 instance profile
   assuming the same role's Jenkins-specific counterpart. Neither pipeline
   ever touches a static AWS access key.
5. **Deploy**
   - Deploys to `dev` automatically on every push to `main`.
   - Deploys to `prod` only after a manual approval gate:
     - GitHub Actions: the `production` Environment has required
       reviewers configured in repo settings.
     - Jenkins: an `input` step pauses the pipeline for a human to click
       Deploy.
   - After each deploy, `scripts/health_check.sh` polls `/healthz` and
     `/ready` on the freshly deployed service.
   - If health checks fail, `scripts/rollback.sh` immediately reverts the
     Kubernetes Deployment to its previous revision, and
     `scripts/slack_notify.py` posts a failure alert to
     `#platform-alerts`. On success, a success message is posted instead.

## Required checks (branch protection)

Configure the following as required status checks on `main` in
Settings > Branches:

- `build-and-test`
- `tfsec`
- `build-and-scan-image`

This blocks merging any change that fails tests, has a critical
vulnerability in its container image, or introduces an insecure
Terraform pattern.

## Secrets

| Secret | Where | Purpose |
|---|---|---|
| `AWS_GHA_ROLE_ARN` | GitHub Actions repo secret | Role ARN to assume via OIDC (output of `terraform/oidc`) |
| `SLACK_WEBHOOK_URL` | GitHub Actions repo secret + Jenkins credential `slack-webhook-url` | Incoming webhook for pipeline alerts |

No AWS access key/secret pair exists anywhere in this repo, its secrets,
or its pipeline logs.
