output "eso_role_arn" {
  value = module.eso_irsa.role_arn
}

output "rds_temporal_endpoint" {
  value = module.rds_temporal.address
}

output "github_actions_role_arn" {
  value = module.github_oidc.role_arn
}