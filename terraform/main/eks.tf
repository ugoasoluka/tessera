module "eks" {
  source = "./modules/eks-cluster"

  cluster_name    = "tessera"
  cluster_version = "1.35"

  vpc_id     = module.vpc.id
  subnet_ids = values(module.vpc.private_subnet_ids)

  endpoint_public_access  = true
  endpoint_private_access = false

  node_groups = {
    workers = {
      instance_types   = ["t3.medium"]
      desired_capacity = 2
      min_size         = 2
      max_size         = 3
      disk_size        = 30
    }
  }

  eks_add_ons = {
    "vpc-cni"    = {}
    "kube-proxy" = {}
    "coredns"    = {}
  }

  tags = local.tags
}

module "eks_oidc_provider" {
  source = "./modules/eks-oidc-provider"

  oidc_provider_url = module.eks.cluster_oidc_issuer_url
}