output "github_actions_role_arn" {
  description = "ARN of the IAM role GitHub Actions assumes to push to ECR"
  value       = module.github_oidc.role_arn
}