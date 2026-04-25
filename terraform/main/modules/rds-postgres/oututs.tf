output "endpoint" {
  description = "RDS instance connection endpoint (host:port)"
  value       = aws_db_instance.this.endpoint
}

output "address" {
  description = "RDS instance address (host only, no port)"
  value       = aws_db_instance.this.address
}

output "port" {
  description = "Postgres port"
  value       = aws_db_instance.this.port
}

output "instance_id" {
  description = "RDS instance identifier"
  value       = aws_db_instance.this.id
}

output "instance_arn" {
  description = "RDS instance ARN"
  value       = aws_db_instance.this.arn
}

output "security_group_id" {
  description = "Security group ID attached to the RDS instance"
  value       = aws_security_group.this.id
}

output "master_user_secret_arn" {
  description = "ARN of the Secrets Manager secret holding the master user password"
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}

output "database_name" {
  description = "Initial database name"
  value       = aws_db_instance.this.db_name
}

output "master_username" {
  description = "Master username"
  value       = aws_db_instance.this.username
}