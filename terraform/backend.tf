# Auracast Hub - Terraform Backend Configuration
#
# Uncomment and configure for remote state management.
# Run `terraform init` after configuring.

# terraform {
#   backend "s3" {
#     bucket         = "auracast-terraform-state"
#     key            = "terraform.tfstate"
#     region         = "ap-northeast-1"
#     encrypt        = true
#     dynamodb_table = "auracast-terraform-locks"
#   }
# }

# ============================================================================
# S3 Backend Bootstrap (run once to create backend resources)
# ============================================================================
#
# resource "aws_s3_bucket" "terraform_state" {
#   bucket = "auracast-terraform-state"
#
#   lifecycle {
#     prevent_destroy = true
#   }
#
#   tags = {
#     Name = "Terraform State"
#   }
# }
#
# resource "aws_s3_bucket_versioning" "terraform_state" {
#   bucket = aws_s3_bucket.terraform_state.id
#   versioning_configuration {
#     status = "Enabled"
#   }
# }
#
# resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
#   bucket = aws_s3_bucket.terraform_state.id
#
#   rule {
#     apply_server_side_encryption_by_default {
#       sse_algorithm = "AES256"
#     }
#   }
# }
#
# resource "aws_dynamodb_table" "terraform_locks" {
#   name         = "auracast-terraform-locks"
#   billing_mode = "PAY_PER_REQUEST"
#   hash_key     = "LockID"
#
#   attribute {
#     name = "LockID"
#     type = "S"
#   }
#
#   tags = {
#     Name = "Terraform Locks"
#   }
# }
