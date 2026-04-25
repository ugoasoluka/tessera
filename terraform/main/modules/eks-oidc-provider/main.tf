locals {
  create_oidc_provider = var.oidc_provider_arn == ""
}

resource "aws_iam_openid_connect_provider" "eks_oidc" {
  count           = local.create_oidc_provider ? 1 : 0
  client_id_list  = ["sts.amazonaws.com"]
  url             = var.oidc_provider_url
}
