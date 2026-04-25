variable "name" {
  description = "Identifier for the RDS instance and related resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the RDS instance will live"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs (use private subnets across at least 2 AZs)"
  type        = list(string)
}

variable "allowed_security_group_ids" {
  description = "Security group IDs allowed to reach Postgres on the configured port"
  type        = list(string)
  default     = []
}

variable "engine_version" {
  description = "Postgres major.minor version (e.g. 16.4)"
  type        = string
  default     = "16.4"
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "allocated_storage" {
  description = "Initial storage size in GB"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Storage autoscaling cap in GB"
  type        = number
  default     = 100
}

variable "database_name" {
  description = "Initial database to create at instance launch"
  type        = string
  default     = "postgres"
}

variable "master_username" {
  description = "Master username (password is auto-managed via Secrets Manager)"
  type        = string
  default     = "postgres"
}

variable "port" {
  description = "Postgres port"
  type        = number
  default     = 5432
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}