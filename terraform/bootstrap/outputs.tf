output "state_bucket" {
  value       = aws_s3_bucket.tfstate.id
  description = "S3 bucket holding Terraform state"
}

output "lock_table" {
  value       = aws_dynamodb_table.tflock.name
  description = "DynamoDB table for state locking"
}

output "region" {
  value       = var.region
  description = "AWS region (for backend config in main module)"
}