variable "project" {
  description = "Project name used as a resource naming prefix."
  type        = string
}

variable "environment" {
  description = "Environment name (e.g. dev, prod)."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "app_port" {
  description = "Port the application container listens on."
  type        = number
  default     = 8080
}

variable "admin_cidr" {
  description = "CIDR allowed to SSH to the EC2 instance (null disables SSH)."
  type        = string
  default     = null
}
