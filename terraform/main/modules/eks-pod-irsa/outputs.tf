output "role_arn" {
  description = "ARN of the IRSA role"
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Name of the IRSA role"
  value       = aws_iam_role.this.name
}

output "service_account_name" {
  description = "Name of the Kubernetes service account this role trusts"
  value       = var.service_account_name
}

output "namespace" {
  description = "Namespace of the Kubernetes service account this role trusts"
  value       = var.namespace
}