data "aws_iam_policy_document" "eso_secrets_access" {
  statement {
    sid    = "ReadAppSecrets"
    effect = "Allow"

    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]

    resources = [
      for s in aws_secretsmanager_secret.app_secrets : s.arn
    ]
  }
}

module "eso_irsa" {
  source = "./modules/eks-pod-irsa"

  name                 = "tessera-eso"
  namespace            = "external-secrets"
  service_account_name = "external-secrets"

  oidc_provider_arn = module.eks_oidc_provider.oidc_provider_arn
  oidc_provider_url = module.eks_oidc_provider.oidc_provider_url

  inline_policy_json = data.aws_iam_policy_document.eso_secrets_access.json

  tags = local.tags
}