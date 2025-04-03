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
  block_public_acls       = false # Allow ACLs
  block_public_policy     = false  # Allow public bucket policy
  ignore_public_acls      = false # Do not ignore ACLs
  restrict_public_buckets = false  # Allow public access via bucket policy
}

# Set Object Ownership to "Bucket owner preferred" to allow ACLs
resource "aws_s3_bucket_ownership_controls" "avatars_bucket_ownership" {
  bucket = aws_s3_bucket.avatars_bucket.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Bucket policy for avatars bucket to allow public read access
resource "aws_s3_bucket_policy" "avatars_bucket_policy" {
  bucket = aws_s3_bucket.avatars_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = "*"
        Action = "s3:GetObject"
        Resource = "arn:aws:s3:::${var.avatars_bucket_name}/*"
      }
    ]
  })
}

# Tags for documentation (optional, for the state bucket)
locals {
  bucket_tags = {
    Name        = var.bucket_name
    Environment = "Production"
  }
}
