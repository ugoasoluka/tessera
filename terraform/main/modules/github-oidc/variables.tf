variable "role_name" {
  description = "Name of the IAM role that GitHub Actions will assume"
  type        = string
}

variable "github_repo" {
  description = "GitHub repo allowed to assume the role, in 'org/repo' format"
  type        = string
}

variable "ecr_repository_arns" {
  description = "ECR repository ARNs the role is allowed to push to"
  type        = list(string)
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
  default     = {}
}