variable "oidc_provider_url" {
  description = "The OIDC provider URL for the EKS cluster"
  type        = string
}

variable "oidc_provider_arn" {
  description = "The ARN of the OIDC provider, if it already exists"
  type        = string
  default     = ""
}
