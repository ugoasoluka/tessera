variable "name" {
  description = "Name of the IAM role"
  type        = string
}

variable "assume_role_policies" {
  description = "Map of assume role policy statements"
  type = map(object({
    sid     = optional(string)
    effect  = optional(string, "Allow")
    actions = list(string)
    principals = list(object({
      type        = string
      identifiers = list(string)
    }))
  }))
}

variable "policy_attachments" {
  description = "List of managed policy ARNs to attach to the role"
  type        = list(string)
  default     = []
}

variable "create_instance_profile" {
  description = "Whether to create an instance profile for this role"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to the role"
  type        = map(string)
  default     = {}
}