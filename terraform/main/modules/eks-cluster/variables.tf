variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the cluster"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the cluster will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for the cluster control plane and node groups"
  type        = list(string)
}

variable "endpoint_private_access" {
  description = "Whether the EKS private API server endpoint is enabled"
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = "Whether the EKS public API server endpoint is enabled"
  type        = bool
  default     = false
}

variable "cluster_network_ip_family" {
  description = "IP family for pod and service addresses (ipv4 or ipv6)"
  type        = string
  default     = "ipv4"
}

variable "cluster_network_service_cidr" {
  description = "CIDR block for Kubernetes service IPs"
  type        = string
  default     = "172.20.0.0/16"
}

variable "node_groups" {
  description = "Map of node groups to create"
  type = map(object({
    instance_types   = optional(list(string), ["t3.medium"])
    ami_type         = optional(string, "AL2_x86_64")
    desired_capacity = optional(number, 2)
    max_size         = optional(number, 3)
    min_size         = optional(number, 1)
    max_unavailable  = optional(number, 1)
    disk_size        = optional(number, 20)
    taints           = optional(list(map(any)), [])
    labels           = optional(map(string), {})
  }))
}

variable "eks_add_ons" {
  description = "Map of EKS addons to install"
  type        = map(any)
  default     = {}
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}