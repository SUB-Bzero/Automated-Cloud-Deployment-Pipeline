# Partial backend configuration — the concrete values are supplied at
# `terraform init` time (see backend.hcl.example, the Makefile, or the
# CI pipeline) so the same code can target any AWS account/region.
terraform {
  backend "s3" {
    key = "acdp/dev/terraform.tfstate"
  }
}
