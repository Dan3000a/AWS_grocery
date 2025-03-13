variable "bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  type        = string
  default     = "grocerymate-terraform-state"
}

variable "avatars_bucket_name" {
  description = "Name of the S3 bucket for storing avatars"
  type        = string
  default     = "grocerymate-avatars-324037288022"
}