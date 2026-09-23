variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project name used as a resource naming prefix."
  type        = string
  default     = "acdp"
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "dev"
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

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Existing EC2 key pair name used for SSH deploys (create it in the AWS console first)."
  type        = string
  default     = "acdp-key"
}

variable "admin_cidr" {
  description = "CIDR allowed to SSH to the EC2 instance (e.g. your public IP/32). Null disables SSH."
  type        = string
  default     = "0.0.0.0/0"
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "PostgreSQL database name."
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "PostgreSQL master username."
  type        = string
  default     = "appadmin"
}

variable "alarm_email" {
  description = "Email address for CloudWatch alarm notifications (must be confirmed once)."
  type        = string
}

variable "image_tag" {
  description = "ECR image tag pulled at instance first boot; the pipeline deploys exact tags afterwards."
  type        = string
  default     = "latest"
}
