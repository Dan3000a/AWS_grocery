variable "vpc_id" {
  description = "The VPC ID"
  type        = string
  default     = "vpc-08ce6a13cdcb855b3d"
}

variable "subnet_ids" {
  description = "List of subnet IDs for the ALB and ASG"
  type        = list(string)
  default     = ["subnet-0ce96933e071872e9", "subnet-0ee24d103b4660957"]
}

variable "security_group_name" {
  description = "Name of the security group for web instances"
  type        = string
  default     = "grocerymate-ec2-security-group"
}

variable "ssh_cidr" {
  description = "CIDR blocks for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "private_cidr" {
  description = "CIDR blocks for private subnet access (e.g., RDS)"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "manual_ip" {
  description = "Manual IP for SSH access (set to 'auto' to use dynamic IP)"
  type        = string
  default     = "auto"
}

variable "launch_template_id" {
  description = "Launch Template ID for the ASG"
  type        = string
  default     = "lt-083e2148f7457df67"
}

variable "alb_security_group_id" {
  description = "The ID of the ALB Security Group"
  type        = string
}