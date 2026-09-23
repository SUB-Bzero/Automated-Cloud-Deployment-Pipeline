output "vpc_id" {
  description = "ID of the created VPC."
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs (ALB + EC2)."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs (RDS)."
  value       = aws_subnet.private[*].id
}

output "alb_security_group_id" {
  description = "Security group attached to the ALB."
  value       = aws_security_group.alb.id
}

output "app_security_group_id" {
  description = "Security group attached to the EC2 app instance."
  value       = aws_security_group.app.id
}

output "db_security_group_id" {
  description = "Security group attached to the RDS instance."
  value       = aws_security_group.db.id
}
