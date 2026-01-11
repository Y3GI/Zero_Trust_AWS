terraform {
    backend "s3" {}
}

provider "aws" {
    region  = "eu-north-1"
}

data "aws_caller_identity" "current" {}

# Read from S3 backend
data "terraform_remote_state" "vpc_s3" {
    backend = "s3"
    config = {
        bucket         = "dev-terraform-state-${data.aws_caller_identity.current.account_id}"
        key            = "dev/vpc/terraform.tfstate"
        region         = "eu-north-1"
        encrypt        = true
        skip_credentials_validation = true
    }
}

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

data "terraform_remote_state" "bootstrap_s3" {
    backend = "s3"
    config = {
        bucket         = "dev-terraform-state-${data.aws_caller_identity.current.account_id}"
        key            = "dev/bootstrap/terraform.tfstate"
        region         = "eu-north-1"
        encrypt        = true
        skip_credentials_validation = true
    }
}

# Use S3 state directly
locals {
    vpc_state       = data.terraform_remote_state.vpc_s3.outputs
    security_state  = data.terraform_remote_state.security_s3.outputs
    bootstrap_state = data.terraform_remote_state.bootstrap_s3.outputs
}

module "vpc_endpoints" {
    source = "../../../modules/vpc-endpoints"

    env                     = "dev"
    region                  = "eu-north-1"
    vpc_cidr                = "10.0.0.0/16"
    
    # Pass dependencies from remote state with fallback to local
    vpc_id                  = try(local.vpc_state.vpc_id, "vpc-error")
    private_rt_id           = try(local.vpc_state.private_rt_id, "rt-error")
    public_rt_id            = try(local.vpc_state.public_rt_id, "rt-error")
    private_subnet_ids      = try(local.vpc_state.private_subnet_ids, [])
    cloudtrail_bucket_name  = try(local.bootstrap_state.cloudtrail_bucket_name, "bucket-error")
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
