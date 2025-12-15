provider "aws" {
    profile = "default"
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
    vpc_id           = data.terraform_remote_state.vpc.outputs.vpc_id
    kms_key_arn      = data.terraform_remote_state.security.outputs.kms_key_arn
    route_table_ids  = [
        data.terraform_remote_state.vpc.outputs.private_rt_id,
        data.terraform_remote_state.vpc.outputs.public_rt_id
    ]
}

output "dynamodb_table_name" {
    description = "The name of the DynamoDB table"
    value       = module.data_store.dynamodb_table_name
}

output "dynamodb_table_arn" {
    description = "The ARN of the DynamoDB table"
    value       = module.data_store.dynamodb_table_arn
}

output "dynamodb_vpc_endpoint_id" {
    description = "The ID of the DynamoDB VPC endpoint"
    value       = module.data_store.dynamodb_vpc_endpoint_id
}
