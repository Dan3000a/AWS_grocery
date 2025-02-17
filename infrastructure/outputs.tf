# EC2 Web Server Private IP
output "web_server_private_ip" {
  description = "Private IP of the web server"
  value       = module.ec2.instance_private_ip
}

# RDS Database Endpoint (Using Module)
output "db_endpoint" {
  description = "RDS database endpoint"
  value       = module.rds.rds_endpoint
  sensitive   = true  # ✅ Ensures it stays hidden in CLI output
}