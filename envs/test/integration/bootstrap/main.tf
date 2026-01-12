terraform {
    backend "local" {}
}

provider "aws" {
    region  = "eu-north-1"
}

# INTEGRATION TESTING: Bootstrap module deployed independently
# Uses AES256 encryption (no KMS dependency for isolated testing)

data "aws_caller_identity" "current" {}

module "bootstrap" {
    source = "../../../../modules/bootstrap"

    env        = "integration-test"
    region     = "eu-north-1"
    # Don't use KMS for isolated integration testing
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
    description = "The KMS key ID (empty for integration tests)"
    value       = ""
}
