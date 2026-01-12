terraform {
    backend "local" {}
}

provider "aws" {
    region  = "eu-north-1"
}

data "aws_caller_identity" "current" {}

# E2E TESTING: Read from local state files (sibling modules)
# Security must be deployed before data_store
data "terraform_remote_state" "security" {
    backend = "local"
    config = {
        path = "../security/terraform.tfstate"
    }
}

locals {
    security_state = data.terraform_remote_state.security.outputs
}

module "data_store" {
    source = "../../../../modules/data_store"

    env         = "e2e-test"
    region      = "eu-north-1"
    kms_key_arn = local.security_state.kms_key_arn
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