terraform {
    backend "local" {}
}

provider "aws" {
    region  = "eu-north-1"
}

data "aws_caller_identity" "current" {}

# E2E TESTING: Read from local state files (sibling modules)
# VPC and Bootstrap must be deployed before vpc-endpoints
data "terraform_remote_state" "vpc" {
    backend = "local"
    config = {
        path = "../vpc/terraform.tfstate"
    }
}

data "terraform_remote_state" "bootstrap" {
    backend = "local"
    config = {
        path = "../bootstrap/terraform.tfstate"
    }
}

locals {
    vpc_state       = data.terraform_remote_state.vpc.outputs
    bootstrap_state = data.terraform_remote_state.bootstrap.outputs
}

module "vpc_endpoints" {
    source = "../../../../modules/vpc-endpoints"

    env                     = "e2e-test"
    region                  = "eu-north-1"
    vpc_cidr                = "10.0.0.0/16"
    
    # Pass dependencies from local state
    vpc_id                  = local.vpc_state.vpc_id
    private_rt_id           = local.vpc_state.private_rt_id
    public_rt_id            = local.vpc_state.public_rt_id
    private_subnet_ids      = local.vpc_state.private_subnet_ids
    cloudtrail_bucket_name  = local.bootstrap_state.cloudtrail_bucket_name
}


output "s3_vpc_endpoint_id" {
    value = module.vpc_endpoints.s3_vpc_endpoint_id
}

output "secretsmanager_vpc_endpoint_id" {
    value = module.vpc_endpoints.secretsmanager_vpc_endpoint_id
}

output "ssm_vpc_endpoint_id" {
    value = module.vpc_endpoints.ssm_vpc_endpoint_id
}

output "dynamodb_vpc_endpoint_id" {
    value = module.vpc_endpoints.dynamodb_vpc_endpoint_id
}
