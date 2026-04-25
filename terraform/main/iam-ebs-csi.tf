module "ebs_csi_irsa" {
  source = "./modules/eks-pod-irsa"

  name                 = "tessera-ebs-csi"
  namespace            = "kube-system"
  service_account_name = "ebs-csi-controller-sa"

  oidc_provider_arn = module.eks_oidc_provider.oidc_provider_arn
  oidc_provider_url = module.eks_oidc_provider.oidc_provider_url

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy",
  ]

  tags = local.tags
}