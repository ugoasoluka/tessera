locals {
  ecr_repositories = {
    "slack-bot" = {
      image_tag_mutability = "IMMUTABLE"
    }
    "temporal-worker" = {
      image_tag_mutability = "IMMUTABLE"
    }
  }
}

module "ecr" {
  source   = "./modules/ecr"
  for_each = local.ecr_repositories

  name                 = each.key
  project_family       = "tessera"
  image_tag_mutability = each.value.image_tag_mutability
  tags                 = local.tags
}