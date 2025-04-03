output "bastion_sg_id" {
  description = "The ID of the Bastion Security Group"
  value       = aws_security_group.bastion_sg.id
}

# Output the Web Security Group ID
output "web_sg_id" {
  description = "The ID of the Web Security Group"
  value       = aws_security_group.web_sg.id
}