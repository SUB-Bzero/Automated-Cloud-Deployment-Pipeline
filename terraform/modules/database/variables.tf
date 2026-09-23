variable "project" {
  description = "Project name used as a resource naming prefix."
  type        = string
}

variable "environment" {
  description = "Environment name (e.g. dev, prod)."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the DB subnet group."
  type        = list(string)
}

variable "db_security_group_id" {
  description = "Security group that controls access to the database."
  type        = string
}

variable "instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Allocated storage in GB."
  type        = number
  default     = 20
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

variable "engine_version" {
  description = "PostgreSQL engine version (null = account default)."
  type        = string
  default     = null
}

variable "multi_az" {
  description = "Run a standby RDS instance in a second AZ."
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "Days of automatic backups to keep."
  type        = number
  default     = 7
}

variable "deletion_protection" {
  description = "Protect the database from accidental deletion."
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Skip the final DB snapshot on destroy (capstone-friendly)."
  type        = bool
  default     = true
}
