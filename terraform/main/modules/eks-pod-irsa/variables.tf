variable "name" {
  description = "Name of the IAM role"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace where the service account lives"
  type        = string
}

variable "service_account_name" {
  description = "Name of the Kubernetes service account that will assume this role"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider"
  type        = string
}

variable "oidc_provider_url" {
  description = "URL of the EKS OIDC provider"
  type        = string
}

variable "managed_policy_arns" {
  description = "List of AWS managed policy ARNs to attach to the role"
  type        = list(string)
  default     = []
}

variable "inline_policy_json" {
  description = "JSON-encoded inline policy document. Only used when create_inline_policy = true."
  type        = string
  default     = null
}

# Separate static toggle so `count` stays known at plan time even when
# inline_policy_json is computed from resource attributes (e.g. ARNs that
# don't exist until apply).
variable "create_inline_policy" {
  description = "Whether to create and attach the inline policy. Set to true when passing inline_policy_json."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}