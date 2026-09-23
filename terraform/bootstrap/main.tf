####################################################################
# Bootstrap module (apply ONCE per AWS account, before anything else)
#
# Creates the remote state backend used by terraform/envs/*:
#   - S3 bucket with versioning + encryption + public access blocked
#   - DynamoDB table for state locking (prevents concurrent applies)
#
# This module keeps its own state locally (terraform.tfstate) because
# the backend it creates cannot store its own state — the classic
# chicken-and-egg. Keep the local terraform.tfstate file safe.
#
# Usage:
#   cd terraform/bootstrap
#   terraform init
#   terraform apply
####################################################################

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

locals {
  bucket_name = var.bucket_name != "" ? var.bucket_name : "${data.aws_caller_identity.current.account_id}-${var.project}-tfstate"
  tags        = {
    Project   = var.project
    ManagedBy = "terraform"
    Purpose   = "terraform-remote-state"
  }
}

# --- S3 bucket for Terraform state files ------------------------------

resource "aws_s3_bucket" "state" {
  bucket        = local.bucket_name
  force_destroy = var.force_destroy

  tags = local.tags
}

# Protect state files against accidental overwrites/deletes.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- DynamoDB table for state locking ---------------------------------

resource "aws_dynamodb_table" "locks" {
  name         = "${var.project}-tf-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = local.tags
}
