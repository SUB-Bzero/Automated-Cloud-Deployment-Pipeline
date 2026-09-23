variable "aws_region" {
  description = "AWS region for the state bucket."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project name used as a resource naming prefix."
  type        = string
  default     = "acdp"
}

variable "bucket_name" {
  description = "Explicit S3 bucket name. Empty = '<account-id>-<project>-tfstate'."
  type        = string
  default     = ""
}

variable "force_destroy" {
  description = "Allow emptying/deleting the state bucket on destroy (capstone-friendly)."
  type        = bool
  default     = true
}
