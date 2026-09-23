# ============================================================
# dev environment values (applied automatically by terraform)
# ============================================================

aws_region        = "us-east-1"
instance_type     = "t3.micro"
db_instance_class = "db.t3.micro"
key_name          = "acdp-key" # create this key pair in the EC2 console

# CloudWatch alarm notifications are sent here.
# IMPORTANT: replace with your own address and confirm the SNS
# subscription email that AWS sends after the first apply.
alarm_email = "your-email@example.com"

# Optional hardening: restrict SSH to your own public IP,
# e.g. "197.80.10.15/32". Default allows SSH from anywhere
# (key-based login only).
# admin_cidr = "0.0.0.0/0"
