variable "availability_zones" {
  description = "List of subnet availability zones."
  type        = list(string)
}

variable "settings" {
  description = "Map of VPC settings. See readme.md for example."
  type        = map(any)
}

variable "tags" {
  description = "Tags to apply to all VPC resources."
  type        = map(any)
  default     = {}
}
