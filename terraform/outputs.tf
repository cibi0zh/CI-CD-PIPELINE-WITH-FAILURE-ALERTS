output "ecr_repository_url" {
  value = module.ecr.repository_url
}

output "github_actions_role_arn" {
  value = module.oidc.github_actions_role_arn
}

output "jenkins_deploy_role_arn" {
  value = module.oidc.jenkins_deploy_role_arn
}
