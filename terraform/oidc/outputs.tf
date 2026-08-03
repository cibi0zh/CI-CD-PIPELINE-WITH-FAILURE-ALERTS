output "github_actions_role_arn" {
  description = "Role ARN to use in aws-actions/configure-aws-credentials"
  value       = aws_iam_role.github_actions_deploy.arn
}

output "oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.github_actions.arn
}

output "jenkins_deploy_role_arn" {
  value = aws_iam_role.jenkins_deploy.arn
}
