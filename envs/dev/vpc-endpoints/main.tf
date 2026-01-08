provider "aws" {

    region  = "eu-north-1"
}

# Get outputs from other modules
data "terraform_remote_state" "vpc" {
    backend = "local"
    config = { path = "../vpc/terraform.tfstate" }
}

data "terraform_remote_state" "security" {
    backend = "local"
    config = { path = "../security/terraform.tfstate" }
}

data "terraform_remote_state" "bootstrap" {
    backend = "local"
    config = { path = "../bootstrap/terraform.tfstate" }
}

module "vpc_endpoints" {
    source = "../../../modules/vpc-endpoints"

    env                     = "dev"
    region                  = "eu-north-1"
    vpc_cidr                = "10.0.0.0/16"
    
    # Pass dependencies from other modules (use try() to handle destroyed dependencies during destroy)
    vpc_id                  = try(data.terraform_remote_state.vpc.outputs.vpc_id, "vpc-destroyed")
    private_rt_id           = try(data.terraform_remote_state.vpc.outputs.private_rt_id, "rt-destroyed")
    public_rt_id            = try(data.terraform_remote_state.vpc.outputs.public_rt_id, "rt-destroyed")
    private_subnet_ids      = try(data.terraform_remote_state.vpc.outputs.private_subnet_ids, [])
    cloudtrail_bucket_name  = try(data.terraform_remote_state.bootstrap.outputs.cloudtrail_bucket_name, "bucket-destroyed")
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
