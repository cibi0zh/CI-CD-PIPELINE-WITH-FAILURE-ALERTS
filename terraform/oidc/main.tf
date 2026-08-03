# =============================================================================
# GitHub Actions OIDC Federation
# -----------------------------------------------------------------------------
# Replaces long-lived static AWS access keys in GitHub Actions with a
# federated OIDC trust relationship. GitHub issues a short-lived signed
# token for each workflow run; AWS trusts that token directly, so there are
# no credentials to rotate, leak, or store as repo secrets.
#
# Jenkins keeps a separate assume-role path (terraform/oidc/jenkins_role.tf)
# since Jenkins typically runs on a long-lived host rather than in GitHub's
# OIDC-issuing environment - it assumes a role via its instance profile
# instead, which is still keyless from the pipeline's point of view.
# =============================================================================

data "tls_certificate" "github_actions" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github_actions.certificates[0].sha1_fingerprint]

  tags = {
    Name = "github-actions-oidc"
  }
}

# -----------------------------------------------------------------------------
# IAM role assumable only by workflows running in this specific repo, scoped
# further to the branches/environments listed in var.trusted_ref_patterns.
# This is the role GitHub Actions assumes via aws-actions/configure-aws-credentials.
# -----------------------------------------------------------------------------
resource "aws_iam_role" "github_actions_deploy" {
  name = "${var.project_name}-gha-deploy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github_actions.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = var.trusted_ref_patterns
        }
      }
    }]
  })

  max_session_duration = 3600

  tags = {
    Name = "${var.project_name}-gha-deploy-role"
  }
}

# -----------------------------------------------------------------------------
# Least-privilege policy: push/pull to ECR, deploy to the target EKS
# cluster, and read the Terraform state used by the CI plan/apply steps.
# Intentionally does NOT grant IAM, VPC, or account-wide write access -
# infrastructure changes to the platform itself go through the separate
# Enterprise-Cloud-Infrastructure-Kubernetes-Platform-AWS repo's own pipeline.
# -----------------------------------------------------------------------------
resource "aws_iam_role_policy" "ecr_push_pull" {
  name = "${var.project_name}-ecr-push-pull"
  role = aws_iam_role.github_actions_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAuth"
        Effect = "Allow"
        Action = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "ECRPushPull"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeImageScanFindings",
          "ecr:StartImageScan",
        ]
        Resource = var.ecr_repository_arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "eks_deploy" {
  name = "${var.project_name}-eks-deploy"
  role = aws_iam_role.github_actions_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "EKSDescribe"
      Effect = "Allow"
      Action = [
        "eks:DescribeCluster",
        "eks:ListClusters",
      ]
      Resource = var.eks_cluster_arn
    }]
  })
}

resource "aws_iam_role_policy" "terraform_state_access" {
  name = "${var.project_name}-tfstate-access"
  role = aws_iam_role.github_actions_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "StateBucketReadWrite"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
        Resource = [var.tfstate_bucket_arn, "${var.tfstate_bucket_arn}/*"]
      },
      {
        Sid      = "StateLock"
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
        Resource = var.tfstate_lock_table_arn
      }
    ]
  })
}

# NOTE: aws-eks pod-level auth is handled separately via the EKS cluster's
# aws-auth ConfigMap / access entries, mapping this role ARN to a
# Kubernetes RBAC group scoped to the "app" namespace only.
