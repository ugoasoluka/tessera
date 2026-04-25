locals {
  processed_addons = {
    for key, addon in var.eks_add_ons : key => {
      version                  = lookup(addon, "version", null)
      resolve_conflicts        = lookup(addon, "resolve_conflicts_on_update", lookup(addon, "resolve_conflicts", null))
      service_account_role_arn = lookup(addon, "service_account_role_arn", null)
      configuration_values     = lookup(addon, "configuration_values", null)
    }
  }
}

resource "aws_launch_template" "ng" {
  for_each    = var.node_groups
  name_prefix = "${var.cluster_name}-${each.key}-"

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = each.value.disk_size
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(
      var.tags,
      {
        "kubernetes.io/cluster/${var.cluster_name}" = "owned"
      }
    )
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(
      var.tags,
      {
        "kubernetes.io/cluster/${var.cluster_name}" = "owned"
      }
    )
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_eks_node_group" "ng" {
  for_each        = var.node_groups
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = each.key
  subnet_ids      = var.subnet_ids
  node_role_arn   = module.eks_worker_role.arn
  instance_types  = each.value.instance_types
  ami_type        = lookup(each.value, "ami_type", "AL2_x86_64")
  labels          = lookup(each.value, "labels", {})

  launch_template {
    id      = aws_launch_template.ng[each.key].id
    version = aws_launch_template.ng[each.key].latest_version
  }

  scaling_config {
    desired_size = each.value.desired_capacity
    max_size     = each.value.max_size
    min_size     = each.value.min_size
  }

  update_config {
    max_unavailable = lookup(each.value, "max_unavailable", 1)
  }

  dynamic "taint" {
    for_each = lookup(each.value, "taints", [])
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }

  tags = var.tags
}

resource "aws_eks_addon" "add_ons" {
  for_each                    = local.processed_addons
  cluster_name                = aws_eks_cluster.eks_cluster.name
  addon_name                  = each.key
  addon_version               = each.value.version
  resolve_conflicts_on_update = each.value.resolve_conflicts
  service_account_role_arn    = each.value.service_account_role_arn
  configuration_values        = each.value.configuration_values

  depends_on = [aws_eks_node_group.ng]
}