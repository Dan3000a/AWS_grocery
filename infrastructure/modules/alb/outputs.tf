# Output the ALB DNS Name
output "alb_dns_name" {
  description = "The DNS name of the ALB"
  value       = aws_lb.grocerymate_alb.dns_name
}

# Output the ALB Zone ID
output "alb_zone_id" {
  description = "The hosted zone ID of the ALB"
  value       = aws_lb.grocerymate_alb.zone_id
}

# Output the ALB Name
output "alb_name" {
  description = "Name of the ALB"
  value       = aws_lb.grocerymate_alb.name
}

# Output the ALB ARN
output "alb_arn" {
  description = "The ARN of the ALB"
  value       = aws_lb.grocerymate_alb.arn
}

# Output the Target Group ARN
output "target_group_arn" {
  description = "The ARN of the Target Group"
  value       = aws_lb_target_group.grocerymate_tg.arn
}