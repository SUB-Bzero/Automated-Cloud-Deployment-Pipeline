output "sns_topic_arn" {
  description = "ARN of the alarm notification topic."
  value       = aws_sns_topic.alerts.arn
}

output "alarm_names" {
  description = "Names of all created CloudWatch alarms."
  value = [
    aws_cloudwatch_metric_alarm.ec2_cpu.alarm_name,
    aws_cloudwatch_metric_alarm.alb_5xx.alarm_name,
    aws_cloudwatch_metric_alarm.alb_unhealthy_hosts.alarm_name,
    aws_cloudwatch_metric_alarm.rds_cpu.alarm_name,
  ]
}

output "dashboard_url" {
  description = "Direct URL of the CloudWatch dashboard."
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${var.project}-${var.environment}-dashboard"
}
