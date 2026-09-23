variable "project" {
  description = "Project name used as a resource naming prefix."
  type        = string
}

variable "environment" {
  description = "Environment name (e.g. dev, prod)."
  type        = string
}

variable "aws_region" {
  description = "AWS region (for the CloudWatch dashboard)."
  type        = string
}

variable "alarm_email" {
  description = "Email address that receives CloudWatch alarm notifications."
  type        = string
}

variable "instance_id" {
  description = "EC2 instance ID to alarm on."
  type        = string
}

variable "alb_arn" {
  description = "ALB ARN (for 5xx / unhealthy-host alarm dimensions)."
  type        = string
}

variable "target_group_arn" {
  description = "Target group ARN (for 5xx / unhealthy-host alarm dimensions)."
  type        = string
}

variable "db_instance_identifier" {
  description = "RDS instance identifier to alarm on."
  type        = string
}

variable "cpu_threshold" {
  description = "CPU utilization (%) that triggers an alarm."
  type        = number
  default     = 80
}

variable "http_5xx_threshold" {
  description = "Sum of HTTP 5xx responses in 5 minutes that triggers an alarm."
  type        = number
  default     = 5
}
