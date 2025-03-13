# Data source for existing S3 bucket (Terraform state)
data "aws_s3_bucket" "existing" {
  bucket = var.bucket_name  # Default: "grocerymate-terraform-state"
}

# S3 bucket versioning for the existing bucket
resource "aws_s3_bucket_versioning" "this" {
  bucket = data.aws_s3_bucket.existing.id

  versioning_configuration {
    status = "Enabled"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# New S3 bucket for app data
resource "aws_s3_bucket" "app_bucket" {
  bucket = "grocerymate-app-bucket"
  tags = {
    Name        = "GroceryMate App Bucket"
    Environment = "Production"
  }
}

# Versioning for the app bucket
resource "aws_s3_bucket_versioning" "app_versioning" {
  bucket = aws_s3_bucket.app_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Security settings for the app bucket
resource "aws_s3_bucket_public_access_block" "app_bucket" {
  bucket = aws_s3_bucket.app_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# New S3 bucket for avatar storage
resource "aws_s3_bucket" "avatars_bucket" {
  bucket = var.avatars_bucket_name  # Use variable instead of hardcoded value
  tags = {
    Name        = "GroceryMate Avatars Bucket"
    Environment = "Production"
  }
}

# Versioning for the avatars bucket
resource "aws_s3_bucket_versioning" "avatars_versioning" {
  bucket = aws_s3_bucket.avatars_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Security settings for the avatars bucket
resource "aws_s3_bucket_public_access_block" "avatars_bucket" {
  bucket = aws_s3_bucket.avatars_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Tags for documentation (optional, for the state bucket)
locals {
  bucket_tags = {
    Name        = var.bucket_name
    Environment = "Production"
  }
}

# Outputs for all buckets
output "s3_bucket_arn" {
  value = data.aws_s3_bucket.existing.arn
  description = "ARN of the Terraform state bucket"
}

output "app_bucket_arn" {
  value = aws_s3_bucket.app_bucket.arn
  description = "ARN of the app bucket"
}

output "avatars_bucket_arn" {
  value = aws_s3_bucket.avatars_bucket.arn
  description = "ARN of the avatars bucket"
}