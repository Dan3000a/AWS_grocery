variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "eu-central-1"
}

variable "profile" {
  description = "AWS CLI Profile"
  type        = string
}

variable "ami" {
  description = "Amazon Machine Image (AMI) for EC2"
  type        = string
  default     = "ami-099d3ad9594677fa"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "db_username" {
  description = "Username for the RDS instance"
  type        = string
}

variable "db_password" {
  description = "Password for the RDS instance"
  type        = string
  sensitive   = true
}