output "github_actions_iam_role_arn" {
  value       = module.github_oidc_role.arn
  description = "ARN of IAM role for GitHub Actions"
}

output "github_actions_iam_role_name" {
  value       = module.github_oidc_role.name
  description = "Name of IAM role for GitHub Actions"
}
