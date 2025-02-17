# Root Module Main File

# Terraform Initialization
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.5.0"
}

# AWS Provider
provider "aws" {
  region  = var.aws_region
  profile = var.profile
}

# Call VPC Module
module "vpc" {
  source       = "./modules/vpc"
  vpc_cidr     = var.vpc_cidr
  region       = var.aws_region
}

# Call Security Groups Module
module "security_groups" {
  source = "./modules/security_groups"
  vpc_id = module.vpc.vpc_id
}

# Call EC2 Module
module "ec2" {
  source         = "./modules/ec2"
  ami            = var.ami
  instance_type  = var.instance_type
  key_pair_name  = var.key_pair_name
  instance_name  = var.instance_name
  security_group = module.security_groups.security_group_id
  private_subnets = module.vpc.private_subnets  # ✅ NEW (all subnets)
}

# Call RDS Module
module "rds" {
  source         = "./modules/rds"
  db_username   = var.db_username
  db_password   = var.db_password
  private_subnets = module.vpc.private_subnets  # ✅ NEW (all subnets)
  security_group = module.security_groups.security_group_id
}

# Call S3 Module
module "s3" {
  source      = "./modules/s3"
  bucket_name = "grocerymate-terraform-state"
}

# Call IAM Module
module "iam" {
  source = "./modules/iam"
}

# Outputs (if needed for external consumption)
output "rds_endpoint" {
  description = "RDS endpoint for database connection"
  value       = module.rds.rds_endpoint
}