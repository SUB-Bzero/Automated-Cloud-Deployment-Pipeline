output "db_instance_identifier" {
  description = "RDS instance identifier (used for CloudWatch alarm dimensions)."
  value       = aws_db_instance.this.identifier
}

output "db_endpoint" {
  description = "RDS endpoint host:port."
  value       = "${aws_db_instance.this.address}:${aws_db_instance.this.port}"
}

output "db_address" {
  description = "RDS endpoint hostname."
  value       = aws_db_instance.this.address
}

output "db_name" {
  description = "Database name."
  value       = var.db_name
}

output "ssm_parameter_name" {
  description = "Name of the SSM parameter holding the connection URL."
  value       = aws_ssm_parameter.database_url.name
}

output "ssm_parameter_arn" {
  description = "ARN of the SSM parameter holding the connection URL."
  value       = aws_ssm_parameter.database_url.arn
}
