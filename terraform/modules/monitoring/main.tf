####################################################################
# Monitoring module
#
# Provisions:
#   - SNS topic + email subscription (the alarm notification channel)
#   - Alarm 1: EC2 CPUUtilization > 80% (for 10 minutes)
#   - Alarm 2: ALB HTTP 5xx responses spike (sum over 5 minutes)
#   - Alarm 3: ALB unhealthy target hosts (app down at the health check)
#   - Alarm 4: RDS CPUUtilization > 80% (for 10 minutes)
#   - A CloudWatch dashboard combining the key metrics
####################################################################

locals {
  tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    Module      = "monitoring"
  }

  # CloudWatch ALB metrics use the ARN suffix ("app/name/id" and
  # "targetgroup/name/id"), not the full ARN.
  alb_suffix          = replace(var.alb_arn, "/^.*:loadbalancer\\//", "")
  target_group_suffix = replace(var.target_group_arn, "/^.*:targetgroup\\//", "")
}

# --- Notification channel ---------------------------------------------

resource "aws_sns_topic" "alerts" {
  name = "${var.project}-${var.environment}-alerts"

  tags = local.tags
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# --- Alarm 1: EC2 CPU > 80% --------------------------------------------

resource "aws_cloudwatch_metric_alarm" "ec2_cpu" {
  alarm_name          = "${var.project}-${var.environment}-ec2-cpu-high"
  alarm_description   = "EC2 CPU utilization has exceeded ${var.cpu_threshold}% for 10 minutes."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = var.cpu_threshold
  unit                = "Percent"
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = var.instance_id
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = local.tags
}

# --- Alarm 2: HTTP 5xx error spike through the ALB ----------------------

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.project}-${var.environment}-alb-5xx-errors"
  alarm_description   = "More than ${var.http_5xx_threshold} HTTP 5xx responses from the app in 5 minutes."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = var.http_5xx_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = local.alb_suffix
    TargetGroup  = local.target_group_suffix
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = local.tags
}

# --- Alarm 3: unhealthy hosts (health check failing) --------------------

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  alarm_name          = "${var.project}-${var.environment}-alb-unhealthy-hosts"
  alarm_description   = "The ALB health check (/health) is failing — the app target is unhealthy."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = local.alb_suffix
    TargetGroup  = local.target_group_suffix
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = local.tags
}

# --- Alarm 4: RDS CPU > 80% ---------------------------------------------

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${var.project}-${var.environment}-rds-cpu-high"
  alarm_description   = "RDS CPU utilization has exceeded 80% for 10 minutes."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = var.db_instance_identifier
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = local.tags
}

# --- Dashboard -----------------------------------------------------------

resource "aws_cloudwatch_dashboard" "this" {
  dashboard_name = "${var.project}-${var.environment}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type       = "metric", x = 0, y = 0, width = 12, height = 6
        properties = {
          title   = "EC2 — CPU Utilization (%)"
          region  = var.aws_region
          period  = 300
          stat    = "Average"
          view    = "timeSeries"
          metrics = [
            ["AWS/EC2", "CPUUtilization", "InstanceId", var.instance_id]
          ]
        }
      },
      {
        type       = "metric", x = 12, y = 0, width = 12, height = 6
        properties = {
          title   = "ALB — HTTP 5xx responses (sum / 5 min)"
          region  = var.aws_region
          period  = 300
          stat    = "Sum"
          view    = "timeSeries"
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", local.alb_suffix, "TargetGroup", local.target_group_suffix]
          ]
        }
      },
      {
        type       = "metric", x = 0, y = 6, width = 12, height = 6
        properties = {
          title   = "ALB — Unhealthy host count"
          region  = var.aws_region
          period  = 60
          stat    = "Maximum"
          view    = "timeSeries"
          metrics = [
            ["AWS/ApplicationELB", "UnHealthyHostCount", "LoadBalancer", local.alb_suffix, "TargetGroup", local.target_group_suffix]
          ]
        }
      },
      {
        type       = "metric", x = 12, y = 6, width = 12, height = 6
        properties = {
          title   = "RDS — CPU Utilization (%)"
          region  = var.aws_region
          period  = 300
          stat    = "Average"
          view    = "timeSeries"
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.db_instance_identifier]
          ]
        }
      },
    ]
  })
}
