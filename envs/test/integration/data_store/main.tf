terraform {
    backend "local" {}
}

provider "aws" {
    region  = "eu-north-1"
}

data "aws_caller_identity" "current" {}

# INTEGRATION TESTING: Mock values for isolated module testing
# These values allow the data_store module to be tested independently
# without requiring Security module to be deployed first
locals {
    # Mock Security values
    mock_kms_key_arn = "arn:aws:kms:eu-north-1:000000000000:key/mock-integration-test-key"
}

module "data_store" {
    source = "../../../../modules/data_store"

    env         = "integration-test"
    region      = "eu-north-1"
    kms_key_arn = local.mock_kms_key_arn
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
