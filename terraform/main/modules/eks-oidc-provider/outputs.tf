output "oidc_provider_arn" {
  description = "The ARN of the OIDC provider"
  value       = local.create_oidc_provider ? aws_iam_openid_connect_provider.eks_oidc[0].arn : var.oidc_provider_arn
}

output "oidc_provider_url" {
  description = "The URL of the OIDC provider"
  value       = var.oidc_provider_url
}
