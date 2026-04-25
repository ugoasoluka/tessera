# Cluster security group

resource "aws_security_group" "eks_cluster" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "EKS cluster security group"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-cluster-sg"
    }
  )
}

resource "aws_vpc_security_group_egress_rule" "eks_cluster_egress" {
  security_group_id = aws_security_group.eks_cluster.id
  description       = "Allow cluster egress to internet"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "eks_cluster_ingress_from_workers" {
  security_group_id            = aws_security_group.eks_cluster.id
  description                  = "Allow pods to communicate with the cluster API server"
  referenced_security_group_id = aws_security_group.eks_worker.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "eks_cluster_ingress_self" {
  security_group_id            = aws_security_group.eks_cluster.id
  description                  = "Allow nodes within the cluster SG to communicate"
  referenced_security_group_id = aws_security_group.eks_cluster.id
  ip_protocol                  = "-1"
}

# Worker security group

resource "aws_security_group" "eks_worker" {
  name        = "${var.cluster_name}-worker-sg"
  description = "EKS worker node security group"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-worker-sg"
    }
  )
}

resource "aws_vpc_security_group_egress_rule" "eks_worker_egress" {
  security_group_id = aws_security_group.eks_worker.id
  description       = "Allow worker egress to internet"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "eks_worker_ingress_self" {
  security_group_id            = aws_security_group.eks_worker.id
  description                  = "Allow workers to communicate with each other"
  referenced_security_group_id = aws_security_group.eks_worker.id
  ip_protocol                  = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "eks_worker_ingress_from_cluster" {
  security_group_id            = aws_security_group.eks_worker.id
  description                  = "Allow workers to receive traffic from the cluster control plane"
  referenced_security_group_id = aws_security_group.eks_cluster.id
  from_port                    = 1024
  to_port                      = 65535
  ip_protocol                  = "tcp"
}