# Replacing static AWS keys with OIDC

## Why

Static IAM access keys stored as CI secrets are long-lived, easy to
accidentally leak in logs or forks, and have to be rotated manually. OIDC
federation removes the credential entirely: GitHub (or Jenkins, via its
instance profile) proves its identity to AWS with a short-lived signed
token, and AWS hands back temporary session credentials scoped to exactly
one IAM role - no secret ever stored, no rotation to remember.

## How it's wired up (GitHub Actions)

1. `terraform/oidc` creates an `aws_iam_openid_connect_provider` trusting
   `token.actions.githubusercontent.com`.
2. It creates an IAM role (`github_actions_deploy`) whose trust policy only
   allows `sts:AssumeRoleWithWebIdentity` from that provider, further
   restricted by the token's `sub` claim to specific branches/environments
   of this exact repo (see `var.trusted_ref_patterns`).
3. The role is granted least-privilege permissions: push/pull on the one
   ECR repo this project owns, `DescribeCluster` on the target EKS cluster,
   and read/write on the shared Terraform state bucket/lock table - nothing
   account-wide.
4. In the workflow (`.github/workflows/ci-cd.yml`), the job declares
   `permissions: id-token: write`, then
   `aws-actions/configure-aws-credentials` exchanges the GitHub-issued OIDC
   token for temporary AWS credentials scoped to that role.

## How it's wired up (Jenkins)

Jenkins doesn't run inside GitHub's OIDC-issuing environment, so it uses a
different but equally keyless path: the Jenkins controller's EC2 instance
already has an IAM instance profile, and `terraform/oidc/jenkins_role.tf`
lets that instance role assume a scoped `jenkins_deploy` role (with an
external ID as an extra confused-deputy guard). Same end result - no
access key ever stored in a Jenkins credential.

## Migration notes

If this pipeline previously used `AWS_ACCESS_KEY_ID` /
`AWS_SECRET_ACCESS_KEY` secrets, the migration is:

1. `terraform apply` in `terraform/` to create the OIDC provider and roles.
2. Set the `AWS_GHA_ROLE_ARN` repo secret to the `github_actions_role_arn`
   output.
3. Delete the old `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` secrets.
4. Deactivate and delete the corresponding IAM user access key in AWS.
