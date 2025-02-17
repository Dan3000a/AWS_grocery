output "rds_endpoint" {
  description = "The endpoint of the RDS instance"
  value       = aws_db_instance.grocery_db.endpoint
  sensitive   = true  # ✅ Hides endpoint in Terraform output for security
}