module "rds_temporal" {
  source = "./modules/rds-postgres"

  name           = "tessera-temporal"
  vpc_id         = module.vpc.id
  subnet_ids     = values(module.vpc.data_subnet_ids)
  engine_version = "16.13"
  instance_class = "db.t4g.micro"

  allowed_security_group_ids = [
    module.eks.worker_security_group_id,
  ]

  tags = local.tags
}