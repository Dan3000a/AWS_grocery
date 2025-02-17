variable "db_username" {
  description = "The master username for the RDS database"
  type        = string
}

variable "db_password" {
  description = "The master password for the RDS database"
  type        = string
  sensitive   = true
}

variable "private_subnets" {
  description = "List of Private Subnet IDs for RDS"
  type        = list(string)
}

variable "security_group" {
  description = "Security group ID for the RDS instance"
  type        = string
}