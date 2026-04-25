resource "aws_eks_cluster" "eks_cluster" {
  name     = var.cluster_name
  role_arn = module.eks_service_role.arn
  version  = var.cluster_version

  vpc_config {
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
    security_group_ids      = [aws_security_group.eks_cluster.id]
    subnet_ids              = var.subnet_ids
  }

  kubernetes_network_config {
    ip_family         = var.cluster_network_ip_family
    service_ipv4_cidr = var.cluster_network_service_cidr
  }

  tags = var.tags
}