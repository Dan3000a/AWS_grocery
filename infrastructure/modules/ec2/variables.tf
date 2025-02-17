variable "ami" {
  description = "AMI ID for the EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "Instance type for EC2"
  type        = string
}

variable "key_pair_name" {
  description = "Name of the key pair"
  type        = string
}

variable "instance_name" {
  description = "EC2 instance name"
  type        = string
}

variable "security_group" {
  description = "Security group ID for EC2"
  type        = string
}

variable "private_subnets" {
  description = "List of Private Subnet IDs"
  type        = list(string)
}