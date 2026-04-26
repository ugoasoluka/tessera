
output "role_arn" {
  description = "ARN of the IAM role GitHub Actions assumes to push to ECR."
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Name of the IAM role (matches var.role_name)."
  value       = aws_iam_role.this.name
}

output "oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC provider in this account."
  value       = aws_iam_openid_connect_provider.github.arn
}
