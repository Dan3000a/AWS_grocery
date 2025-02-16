provider "aws" {
  region  = var.aws_region
  profile = var.profile
}

module "vpc" {
  source               = "./modules/vpc"
  vpc_cidr            = "10.0.0.0/16"
  public_subnet_cidr  = "10.0.1.0/24"
  private_subnet_cidr = "10.0.2.0/24"
  availability_zone   = "eu-central-1a"
}

module "security_groups" {
  source               = "./modules/security_groups"
  ssh_cidr            = var.ssh_cidr
  http_cidr           = var.http_cidr
  security_group_name = var.security_group_name
}

module "ec2" {
  source          = "./modules/ec2"
  ami            = var.ami
  instance_type  = var.instance_type
  key_pair_name  = var.key_pair_name
  instance_name  = var.instance_name
  security_group = module.security_groups.security_group_id
}

module "rds" {
  source         = "./modules/rds"
  db_username   = var.db_username
  db_password   = var.db_password
  private_subnets = module.vpc.private_subnets
  security_group = module.security_groups.security_group_id
}

module "s3" {
  source = "./modules/s3"
  bucket_name = "grocerymate-terraform-state"
}

module "iam" {
  source = "./modules/iam"
}