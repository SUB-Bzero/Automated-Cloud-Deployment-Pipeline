####################################################################
# Compute module
#
# Provisions:
#   - IAM role/instance profile: ECR read + SSM Parameter read + SSM core
#   - EC2 instance bootstrapped with Docker via user_data
#   - Internet-facing Application Load Balancer with an HTTP listener
#   - Target group with a /health health check, targeting the instance
####################################################################

locals {
  tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    Module      = "compute"
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# --- IAM: let the instance pull from ECR and read the DB parameter ----

resource "aws_iam_role" "ec2" {
  name = "${var.project}-${var.environment}-ec2-role"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = local.tags
}

# Pull images from ECR without any stored credentials.
resource "aws_iam_role_policy_attachment" "ecr_read" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Session Manager access (safer than keeping SSH ports open).
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Read only the one SSM parameter that holds the database URL.
resource "aws_iam_role_policy" "read_db_parameter" {
  name = "${var.project}-${var.environment}-read-db-parameter"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter", "ssm:GetParameters"]
        Resource = var.db_ssm_parameter_arn
      },
    ]
  })
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.project}-${var.environment}-ec2-profile"
  role = aws_iam_role.ec2.name

  tags = local.tags
}

# --- EC2 instance ------------------------------------------------------

resource "aws_instance" "app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_ids[0]
  vpc_security_group_ids = [var.app_security_group_id]
  key_name               = var.key_name

  iam_instance_profile = aws_iam_instance_profile.this.name
  user_data            = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    aws_region         = var.aws_region
    project            = var.project
    environment        = var.environment
    app_port           = var.app_port
    ecr_repository_url = var.ecr_repository_url
    image_tag          = var.image_tag
    db_parameter_name  = var.db_ssm_parameter_name
  })
  user_data_replace_on_change = true

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_tokens = "required" # enforce IMDSv2
  }

  tags = merge(local.tags, { Name = "${var.project}-${var.environment}-app" })
}

# --- Application Load Balancer ----------------------------------------

resource "aws_lb" "this" {
  name               = "${var.project}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  drop_invalid_header_fields = true

  tags = merge(local.tags, { Name = "${var.project}-${var.environment}-alb" })
}

resource "aws_lb_target_group" "app" {
  name     = "${var.project}-${var.environment}-tg"
  port     = var.app_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  target_type = "instance"

  health_check {
    enabled             = true
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  deregistration_delay = 30

  tags = merge(local.tags, { Name = "${var.project}-${var.environment}-tg" })
}

resource "aws_lb_target_group_attachment" "app" {
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.app.id
  port             = var.app_port
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  tags = local.tags
}
