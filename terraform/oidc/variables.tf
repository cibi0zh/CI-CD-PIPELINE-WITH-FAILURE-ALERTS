variable "project_name" {
  type    = string
  default = "cicd-pipeline"
}

variable "trusted_ref_patterns" {
  description = <<-DESC
    List of GitHub OIDC "sub" claim patterns allowed to assume this role,
    e.g. "repo:cibi0zh/CI-CD-PIPELINE-WITH-FAILURE-ALERTS:ref:refs/heads/main"
    for pushes to main, or ":environment:production" for a protected
    GitHub Environment deployment.
  DESC
  type = list(string)
  default = [
    "repo:cibi0zh/CI-CD-PIPELINE-WITH-FAILURE-ALERTS:ref:refs/heads/main",
    "repo:cibi0zh/CI-CD-PIPELINE-WITH-FAILURE-ALERTS:pull_request",
    "repo:cibi0zh/CI-CD-PIPELINE-WITH-FAILURE-ALERTS:environment:production",
  ]
}

variable "ecr_repository_arn" {
  description = "ARN of the ECR repository this role may push/pull"
  type        = string
}

variable "eks_cluster_arn" {
  description = "ARN of the target EKS cluster (provisioned by the platform repo)"
  type        = string
}

variable "tfstate_bucket_arn" {
  type = string
}

variable "tfstate_lock_table_arn" {
  type = string
}

variable "jenkins_instance_role_arn" {
  description = "ARN of the IAM role attached to the Jenkins controller's EC2 instance profile"
  type        = string
  default     = ""
}

variable "jenkins_external_id" {
  description = "External ID required when Jenkins assumes jenkins_deploy, as an extra confused-deputy guard"
  type        = string
  default     = "jenkins-cicd-pipeline"
}
