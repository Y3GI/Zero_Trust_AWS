provider "aws" {
    profile = "default"
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

    vpc_id                   = data.terraform_remote_state.vpc.outputs.vpc_id
    vpc_cidr                 = "10.0.0.0/16"
    private_subnet_ids       = data.terraform_remote_state.vpc.outputs.private_subnet_ids
    route_table_ids          = [
        data.terraform_remote_state.vpc.outputs.private_rt_id,
        data.terraform_remote_state.vpc.outputs.public_rt_id
    ]
    cloudtrail_bucket_name   = data.terraform_remote_state.bootstrap.outputs.cloudtrail_bucket_name
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
