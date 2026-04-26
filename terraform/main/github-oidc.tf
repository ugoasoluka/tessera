module "github_oidc" {
  source = "./modules/github-oidc"

  role_name   = "tessera-gha-ecr-push"
  github_repo = "ugoasoluka/tessera"

  ecr_repository_arns = [for repo in module.ecr : repo.repository_arn]

  tags = local.tags
}