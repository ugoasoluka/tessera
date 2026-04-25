data "aws_partition" "current" {}

module "eks_service_role" {
  source = "../eks-iam-role"

  name = "${var.cluster_name}-service-role"

  policy_attachments = [
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSClusterPolicy",
  ]

  assume_role_policies = {
    eks_service = {
      sid     = "EKSClusterAssumeRole"
      effect  = "Allow"
      actions = ["sts:AssumeRole"]
      principals = [
        {
          type        = "Service"
          identifiers = ["eks.amazonaws.com"]
        }
      ]
    }
  }

  create_instance_profile = false
  tags                    = var.tags
}

module "eks_worker_role" {
  source = "../eks-iam-role"

  name = "${var.cluster_name}-worker-role"

  policy_attachments = [
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
  ]

  assume_role_policies = {
    ec2_assume = {
      sid     = "EKSNodeAssumeRole"
      effect  = "Allow"
      actions = ["sts:AssumeRole"]
      principals = [
        {
          type        = "Service"
          identifiers = ["ec2.amazonaws.com"]
        }
      ]
    }
  }

  create_instance_profile = true
  tags                    = var.tags
}