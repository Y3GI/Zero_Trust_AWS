terraform {
    backend "local" {}
}

provider "aws" {
    region  = "eu-north-1"
}

# E2E TESTING: Bootstrap module deployed first
# Creates S3 buckets for state and CloudTrail
# Uses AES256 encryption (KMS created later by security module)

data "aws_caller_identity" "current" {}

module "bootstrap" {
    source = "../../../../modules/bootstrap"

    env        = "e2e-test"
    region     = "eu-north-1"
    # Don't use KMS since security hasn't been deployed yet
    kms_key_id = ""
}

output "terraform_state_bucket_id" {
    description = "The ID of the S3 bucket for Terraform state"
    value       = module.bootstrap.terraform_state_bucket_id
}

output "terraform_state_bucket_name" {
    description = "The name of the S3 bucket for Terraform state"
    value       = module.bootstrap.terraform_state_bucket_name
}

output "cloudtrail_bucket_id" {
    description = "The ID of the S3 bucket for CloudTrail logs"
    value       = module.bootstrap.cloudtrail_bucket_id
}

output "cloudtrail_bucket_name" {
    description = "The name of the S3 bucket for CloudTrail logs"
    value       = module.bootstrap.cloudtrail_bucket_name
}

output "kms_key_id" {
    description = "The KMS key ID (empty until security module runs)"
    value       = ""
}
