# =============================================================================
# Root stack - composes the oidc and ecr modules for this pipeline.
# Reuses the same S3/DynamoDB remote-state backend created by the platform
# repo's terraform/backend-setup, under its own state key so the two repos
# never touch each other's state.
# =============================================================================

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "enterprise-cloud-platform-tfstate-<ACCOUNT_ID>"
    key            = "cicd-pipeline/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "enterprise-cloud-platform-tf-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "cicd-pipeline"
      ManagedBy = "terraform"
    }
  }
}

module "ecr" {
  source = "./ecr"

  repository_name = var.ecr_repository_name
  # push_role_arns is filled in below once the oidc module has created the
  # roles - Terraform resolves the dependency automatically.
  push_role_arns = [
    module.oidc.github_actions_role_arn,
    module.oidc.jenkins_deploy_role_arn,
  ]
}

module "oidc" {
  source = "./oidc"

  project_name            = var.project_name
  trusted_ref_patterns    = var.trusted_ref_patterns
  ecr_repository_arn      = module.ecr.repository_arn
  eks_cluster_arn         = var.eks_cluster_arn
  tfstate_bucket_arn      = var.tfstate_bucket_arn
  tfstate_lock_table_arn  = var.tfstate_lock_table_arn
  jenkins_instance_role_arn = var.jenkins_instance_role_arn
}
