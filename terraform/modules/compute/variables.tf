variable "project" {
  description = "Project name used as a resource naming prefix."
  type        = string
}

variable "environment" {
  description = "Environment name (e.g. dev, prod)."
  type        = string
}

variable "aws_region" {
  description = "AWS region the resources live in."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs (ALB + EC2)."
  type        = list(string)
}

variable "app_security_group_id" {
  description = "Security group for the EC2 instance."
  type        = string
}

variable "alb_security_group_id" {
  description = "Security group for the ALB."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Name of an existing EC2 key pair used for SSH deploys."
  type        = string
}

variable "app_port" {
  description = "Port the application container listens on."
  type        = number
  default     = 8080
}

variable "ecr_repository_url" {
  description = "ECR repository URL to pull the app image from."
  type        = string
}

variable "image_tag" {
  description = "Image tag pulled at first boot (the CI/CD pipeline deploys specific tags afterwards)."
  type        = string
  default     = "latest"
}

variable "db_ssm_parameter_name" {
  description = "SSM parameter name holding the database connection URL."
  type        = string
}

variable "db_ssm_parameter_arn" {
  description = "SSM parameter ARN to grant read access to."
  type        = string
}
