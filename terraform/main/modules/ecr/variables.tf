variable "name" {
  description = "Name of the ECR repository"
  type        = string
}

variable "project_family" {
  description = "Project family the repository belongs to. Repo name becomes <project_family>/<name>."
  type        = string
}

variable "image_tag_mutability" {
  description = "Tag mutability setting for the repository"
  type        = string
  default     = "MUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability must be either MUTABLE or IMMUTABLE"
  }
}

variable "force_delete" {
  description = "Allow Terraform to delete the repository even if it contains images"
  type        = bool
  default     = true
}

variable "scan_on_push" {
  description = "Enable image scanning on push"
  type        = bool
  default     = true
}

variable "apply_lfc_policy" {
  description = "Apply the lifecycle policy"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to the repository"
  type        = map(any)
  default     = {}
}