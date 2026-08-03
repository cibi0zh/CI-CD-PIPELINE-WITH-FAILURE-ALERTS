variable "repository_name" {
  type    = string
  default = "cicd-pipeline/healthcheck"
}

variable "push_role_arns" {
  description = "IAM role ARNs allowed to push images (GitHub Actions OIDC role, Jenkins deploy role)"
  type        = list(string)
  default     = []
}
