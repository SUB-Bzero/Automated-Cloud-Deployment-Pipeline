####################################################################
# Database module
#
# Provisions:
#   - An RDS PostgreSQL instance in the private subnets
#   - A random master password (never stored in plain text in the repo)
#   - The full connection URL stored in SSM Parameter Store as a
#     SecureString, which the EC2 instance reads at deploy time via
#     its IAM instance role (no credentials on the host or in the repo)
####################################################################

locals {
  tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    Module      = "database"
  }
}

resource "random_password" "db" {
  length  = 32
  special = false # keep the value URL-safe when embedded in a connection URL
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.project}-${var.environment}-db-subnets"
  subnet_ids = var.private_subnet_ids

  tags = merge(local.tags, { Name = "${var.project}-${var.environment}-db-subnets" })
}

resource "aws_db_instance" "this" {
  identifier = "${var.project}-${var.environment}-db"

  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.db_security_group_id]

  publicly_accessible = false
  multi_az            = var.multi_az

  backup_retention_period    = var.backup_retention_days
  auto_minor_version_upgrade = true

  deletion_protection = var.deletion_protection
  skip_final_snapshot = var.skip_final_snapshot

  tags = merge(local.tags, { Name = "${var.project}-${var.environment}-db" })
}

# Full connection URL, stored encrypted and fetched by the EC2 host
# (and the deploy script) through the instance IAM role.
resource "aws_ssm_parameter" "database_url" {
  name        = "/${var.project}/${var.environment}/database_url"
  description = "RDS PostgreSQL connection URL for the app"
  type        = "SecureString"
  value       = format(
    "postgresql://%s:%s@%s:%d/%s",
    var.db_username,
    random_password.db.result,
    aws_db_instance.this.address,
    aws_db_instance.this.port,
    var.db_name,
  )

  tags = local.tags
}
