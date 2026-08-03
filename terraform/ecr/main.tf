# =============================================================================
# ECR Repository
# -----------------------------------------------------------------------------
# Container registry for the health-check service (and any other services
# this pipeline builds). Scan-on-push catches known-vulnerable base images
# and OS packages immediately, ahead of the Trivy scan that runs in CI
# against the fully-built application image.
# =============================================================================

resource "aws_ecr_repository" "app" {
  name                 = var.repository_name
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = var.repository_name
  }
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep only the last 20 tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "main", "sha"]
          countType     = "imageCountMoreThan"
          countNumber   = 20
        }
        action = { type = "expire" }
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Repository policy: only the GitHub Actions / Jenkins deploy roles (from
# terraform/oidc) may push. Pulls are left to the EKS node role, granted
# separately in the platform repo via AmazonEC2ContainerRegistryReadOnly.
# -----------------------------------------------------------------------------
resource "aws_ecr_repository_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowPipelinePush"
      Effect    = "Allow"
      Principal = { AWS = var.push_role_arns }
      Action = [
        "ecr:BatchCheckLayerAvailability",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
      ]
    }]
  })
}
