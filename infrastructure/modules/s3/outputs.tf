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