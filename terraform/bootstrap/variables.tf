variable "region" {
  type        = string
  description = "AWS region for state resources"
}

variable "state_bucket_name" {
  type        = string
  description = "Globally unique S3 bucket name for Terraform state"
}

variable "lock_table_name" {
  type        = string
  description = "DynamoDB table name for Terraform state locking"
}