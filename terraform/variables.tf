variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "cicd-pipeline"
}

variable "ecr_repository_name" {
  type    = string
  default = "cicd-pipeline/healthcheck"
}

variable "trusted_ref_patterns" {
  type = list(string)
  default = [
    "repo:cibi0zh/CI-CD-PIPELINE-WITH-FAILURE-ALERTS:ref:refs/heads/main",
    "repo:cibi0zh/CI-CD-PIPELINE-WITH-FAILURE-ALERTS:pull_request",
    "repo:cibi0zh/CI-CD-PIPELINE-WITH-FAILURE-ALERTS:environment:production",
  ]
}

variable "eks_cluster_arn" {
  description = "ARN of the EKS cluster provisioned by the platform repo (Enterprise-Cloud-Infrastructure-Kubernetes-Platform-AWS)"
  type        = string
}

variable "tfstate_bucket_arn" {
  type = string
}

variable "tfstate_lock_table_arn" {
  type = string
}

variable "jenkins_instance_role_arn" {
  type    = string
  default = ""
}
