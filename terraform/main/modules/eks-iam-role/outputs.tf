output "arn" {
  description = "ARN of the IAM role"
  value       = aws_iam_role.this.arn
}

output "name" {
  description = "Name of the IAM role"
  value       = aws_iam_role.this.name
}

output "instance_profile_arn" {
  description = "ARN of the instance profile, if created"
  value       = var.create_instance_profile ? aws_iam_instance_profile.this[0].arn : null
}

output "instance_profile_name" {
  description = "Name of the instance profile, if created"
  value       = var.create_instance_profile ? aws_iam_instance_profile.this[0].name : null
}