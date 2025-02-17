# AWS Region
variable "region" {
  description = "AWS region for deployment"
  type        = string
  default     = "eu-central-1"
}

# AWS Profile (For AWS CLI authentication)
variable "profile" {
  description = "AWS CLI Profile for authentication"
  type        = string
}

# VPC CIDR Block
variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

# EC2 Configuration
variable "ami" {
  description = "Amazon Machine Image (AMI) for EC2 instance"
  type        = string
  default     = "ami-099d3ad9594677fa"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

# Database Credentials
variable "db_username" {
  description = "Username for the RDS instance"
  type        = string
}

variable "db_password" {
  description = "Password for the RDS instance"
  type        = string
  sensitive   = true
}