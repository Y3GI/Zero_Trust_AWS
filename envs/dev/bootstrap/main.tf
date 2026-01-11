terraform {
    backend "local" {}
}

provider "aws" {
    region  = "eu-north-1"
}

# Bootstrap deploys first, so it doesn't reference security
# It uses simple AES256 encryption for the state bucket
# After security is deployed with KMS key, you can manually update bootstrap to use KMS

data "aws_caller_identity" "current" {}

module "bootstrap" {
    source = "../../../modules/bootstrap"

    env = "dev"
    region = "eu-north-1"
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
