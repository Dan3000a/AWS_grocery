# Root Module Main File

# Terraform Initialization
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.0"
    }
  }
  required_version = ">= 1.5.0"
}

# AWS Provider
provider "aws" {
  region  = var.aws_region
  profile = var.profile
}

# Generate SSH Key Pair - Must be declared before EC2 module
resource "aws_key_pair" "generated" {
  key_name   = "grocerymate-key"
  public_key = file("~/.ssh/id_rsa.pub") # Ensure this file exists locally
}

# Call VPC module - order: 1. VPC 2. Security Groups
module "vpc" {
  source   = "./modules/vpc"
  vpc_cidr = var.vpc_cidr
}

# Security group module with resolved IP (using dynamic IPv4)
module "security_groups" {
  source                = "./modules/security_groups"
  vpc_id                = module.vpc.vpc_id
  security_group_name   = "example-sg"
  manual_ip             = var.manual_ip
  ssh_cidr              = var.manual_ip == "auto" ? [format("%s/32", data.external.my_ip[0].result.ip)] : [var.manual_ip]
  http_cidr             = ["0.0.0.0/0"]
  private_cidr          = ["10.0.0.0/16"]
  alb_security_group_id = module.vpc.alb_security_group_id
}

# EC2 module call
module "ec2" {
  source                    = "./modules/ec2"
  ami                       = var.ami
  instance_type             = var.instance_type
  key_pair_name             = aws_key_pair.generated.key_name
  instance_name             = var.instance_name
  security_group            = module.security_groups.security_group_id
  iam_role_name             = module.iam.ec2_role_name
  vpc_id                    = module.vpc.vpc_id
  public_subnets            = module.vpc.public_subnets
  bastion_security_group_id = module.security_groups.bastion_sg_id
  iam_instance_profile_name = var.iam_instance_profile_name  # Use the variable instead of hardcoding
}

# Call RDS Module
module "rds" {
  source                     = "./modules/rds"
  db_identifier              = var.db_identifier
  db_arn                     = var.db_arn
  private_subnets            = module.vpc.private_subnets
  security_group             = module.security_groups.security_group_id
  db_credentials_secret_name = var.db_credentials_secret_name
}

# Call IAM Module & Pass Secrets Manager ARN
module "iam" {
  source                    = "./modules/iam"
  db_credentials_secret_arn = module.rds.db_credentials_secret_arn
}

# Call S3 Module
module "s3" {
  source      = "./modules/s3"
  bucket_name = "grocerymate-terraform-state"
}

# ALB Module
module "alb" {
  source                = "./modules/alb"
  vpc_id                = module.vpc.vpc_id
  public_subnets        = module.vpc.public_subnets
  alb_security_group_id = module.vpc.alb_security_group_id
}

# ASG Module - Use dynamic target_group_arn from module.alb
module "asg" {
  source                 = "./modules/asg"
  subnet_ids             = var.subnet_ids
  launch_template_id     = var.launch_template_id
  launch_template_version = var.launch_template_version
  target_group_arn       = module.alb.aws_lb_target_group_grocerymate_tg_arn  # Dynamic ARN
}

# Route53 Module
module "route53" {
  source       = "./modules/route53"
  alb_dns_name = module.alb.alb_dns_name
  alb_zone_id  = module.alb.alb_zone_id
}