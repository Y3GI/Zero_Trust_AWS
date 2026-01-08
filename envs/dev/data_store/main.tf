provider "aws" {

    region  = "eu-north-1"
}

# Get the VPC and Security outputs
data "terraform_remote_state" "vpc" {
    backend = "local"
    config = {
        path = "../vpc/terraform.tfstate"
    }
}

data "terraform_remote_state" "security" {
    backend = "local"
    config = {
        path = "../security/terraform.tfstate"
    }
}

module "data_store" {
    source = "../../../modules/data_store"

    env              = "dev"
    region           = "eu-north-1"
    
    # Pass KMS key from security module (use try() to handle destroyed dependencies during destroy)
    kms_key_arn      = try(data.terraform_remote_state.security.outputs.kms_key_arn, "arn:aws:kms:eu-north-1:000000000000:key/destroyed")
}

output "dynamodb_table_name" {
    description = "The name of the DynamoDB table"
    value       = module.data_store.dynamodb_table_name
}

output "dynamodb_table_arn" {
    description = "The ARN of the DynamoDB table"
    value       = module.data_store.dynamodb_table_arn
}