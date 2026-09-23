output "state_bucket" {
  description = "Name of the S3 bucket that stores Terraform remote state."
  value       = aws_s3_bucket.state.bucket
}

output "locks_table" {
  description = "Name of the DynamoDB table used for state locking."
  value       = aws_dynamodb_table.locks.name
}

output "init_command" {
  description = "The terraform init command to run in terraform/envs/dev."
  value       = "terraform init -backend-config='bucket=${aws_s3_bucket.state.bucket}' -backend-config='region=${var.aws_region}' -backend-config='dynamodb_table=${aws_dynamodb_table.locks.name}' -backend-config='encrypt=true'"
}
