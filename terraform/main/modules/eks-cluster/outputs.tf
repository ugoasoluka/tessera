output "cluster_id" {
  description = "Name/ID of the EKS cluster"
  value       = aws_eks_cluster.eks_cluster.id
}

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.eks_cluster.name
}

output "cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = aws_eks_cluster.eks_cluster.arn
}

output "cluster_endpoint" {
  description = "Endpoint of the Kubernetes API server"
  value       = aws_eks_cluster.eks_cluster.endpoint
}

output "cluster_ca_certificate" {
  description = "Base64-encoded CA certificate for the cluster"
  value       = aws_eks_cluster.eks_cluster.certificate_authority[0].data
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL for the cluster (used by the OIDC provider module)"
  value       = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_security_group.eks_cluster.id
}

output "worker_security_group_id" {
  description = "Security group ID attached to the EKS workers"
  value       = aws_security_group.eks_worker.id
}

output "worker_role_arn" {
  description = "ARN of the worker node IAM role"
  value       = module.eks_worker_role.arn
}

output "node_groups" {
  description = "Map of node groups created"
  value       = aws_eks_node_group.ng
}