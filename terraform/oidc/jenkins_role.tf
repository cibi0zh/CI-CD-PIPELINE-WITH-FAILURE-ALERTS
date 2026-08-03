# =============================================================================
# Jenkins deploy role
# -----------------------------------------------------------------------------
# Jenkins runs on a long-lived EC2 host rather than in a short-lived OIDC
# runner, so it can't use the same federated-token trust as GitHub Actions.
# Instead it assumes this role via its own EC2 instance profile
# (ec2:AssumeRole), which is still keyless - no access keys are stored in
# Jenkins credentials or Jenkinsfile at any point. Scope is identical to the
# GitHub Actions role for consistency between the two pipelines.
# =============================================================================

resource "aws_iam_role" "jenkins_deploy" {
  name = "${var.project_name}-jenkins-deploy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = var.jenkins_instance_role_arn }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "sts:ExternalId" = var.jenkins_external_id
        }
      }
    }]
  })

  max_session_duration = 3600

  tags = {
    Name = "${var.project_name}-jenkins-deploy-role"
  }
}

resource "aws_iam_role_policy" "jenkins_ecr_push_pull" {
  name = "${var.project_name}-jenkins-ecr-push-pull"
  role = aws_iam_role.jenkins_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ECRAuth"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
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
        ]
        Resource = var.ecr_repository_arn
      }
    ]
  })
}
