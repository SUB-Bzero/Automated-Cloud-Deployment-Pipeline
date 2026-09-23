output "instance_id" {
  description = "EC2 instance ID (used for the CPU alarm dimension)."
  value       = aws_instance.app.id
}

output "instance_public_ip" {
  description = "Public IP of the EC2 instance (SSH deploy target)."
  value       = aws_instance.app.public_ip
}

output "alb_dns_name" {
  description = "Public DNS name of the application load balancer."
  value       = aws_lb.this.dns_name
}

output "alb_arn" {
  description = "Full ARN of the ALB (for CloudWatch alarm dimensions)."
  value       = aws_lb.this.arn
}

output "target_group_arn" {
  description = "Full ARN of the target group (for CloudWatch alarm dimensions)."
  value       = aws_lb_target_group.app.arn
}
