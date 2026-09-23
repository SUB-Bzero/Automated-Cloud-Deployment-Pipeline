output "app_url" {
  description = "Public application URL (served through the ALB)."
  value       = "http://${module.compute.alb_dns_name}"
}

output "alb_dns_name" {
  description = "Public DNS name of the application load balancer."
  value       = module.compute.alb_dns_name
}

output "ec2_public_ip" {
  description = "Public IP of the EC2 instance (SSH deploy target)."
  value       = module.compute.instance_public_ip
}

output "ecr_repository_url" {
  description = "ECR repository the CI/CD pipeline pushes images to."
  value       = module.ecr.repository_url
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint."
  value       = module.database.db_endpoint
}

output "sns_topic_arn" {
  description = "SNS topic that delivers CloudWatch alarm emails."
  value       = module.monitoring.sns_topic_arn
}

output "cloudwatch_dashboard_url" {
  description = "CloudWatch dashboard URL."
  value       = module.monitoring.dashboard_url
}
