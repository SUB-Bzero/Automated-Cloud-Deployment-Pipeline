variable "project" {
  description = "Project name used as a resource naming prefix."
  type        = string
}

variable "environment" {
  description = "Environment name (e.g. dev, prod)."
  type        = string
}

variable "force_delete" {
  description = "Allow the ECR repository to be deleted even when it still contains images (convenient for capstone teardown)."
  type        = bool
  default     = true
}
