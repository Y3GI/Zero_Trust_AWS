terraform {
    backend "s3" {}
}

provider "aws" {
    region  = "eu-north-1"
}

data "aws_caller_identity" "current" {}

# Read from S3 backend
data "terraform_remote_state" "security_s3" {
    backend = "s3"
    config = {
        bucket         = "dev-terraform-state-${data.aws_caller_identity.current.account_id}"
        key            = "dev/security/terraform.tfstate"
        region         = "eu-north-1"
        encrypt        = true
        skip_credentials_validation = true
    }
}

# Use S3 state directly
locals {
    security_state = data.terraform_remote_state.security_s3.outputs
    kms_key_arn    = try(local.security_state.kms_key_arn, "")
}

module "data_store" {
    source = "../../../modules/data_store"

    env         = "dev"
    region      = "eu-north-1"
    kms_key_arn = local.kms_key_arn
}


output "terraform_locks_table_name" {
    description = "The name of the DynamoDB table for Terraform state locking"
    value       = module.data_store.terraform_locks_table_name
}

output "terraform_locks_table_arn" {
    description = "The ARN of the DynamoDB table for Terraform state locking"
    value       = module.data_store.terraform_locks_table_arn
}

output "dynamodb_table_name" {
    description = "The name of the DynamoDB table"
    value       = module.data_store.dynamodb_table_name
}

output "dynamodb_table_arn" {
    description = "The ARN of the DynamoDB table"
    value       = module.data_store.dynamodb_table_arn
}