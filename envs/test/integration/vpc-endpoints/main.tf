terraform {
    backend "local" {}
}

provider "aws" {
    region  = "eu-north-1"
}

data "aws_caller_identity" "current" {}

# INTEGRATION TESTING: Mock values for isolated module testing
# These values allow the vpc-endpoints module to be tested independently
# without requiring VPC, Security, and Bootstrap modules to be deployed first
locals {
    # Mock VPC values
    mock_vpc_id             = "vpc-mock-integration-test"
    mock_private_rt_id      = "rtb-mock-private"
    mock_public_rt_id       = "rtb-mock-public"
    mock_private_subnet_ids = ["subnet-mock-private-1a", "subnet-mock-private-1b"]
    
    # Mock Bootstrap values
    mock_cloudtrail_bucket_name = "mock-integration-test-cloudtrail-bucket"
}

module "vpc_endpoints" {
    source = "../../../../modules/vpc-endpoints"

    env                     = "integration-test"
    region                  = "eu-north-1"
    vpc_cidr                = "10.0.0.0/16"
    
    # Use mock values for isolated integration testing
    vpc_id                  = local.mock_vpc_id
    private_rt_id           = local.mock_private_rt_id
    public_rt_id            = local.mock_public_rt_id
    private_subnet_ids      = local.mock_private_subnet_ids
    cloudtrail_bucket_name  = local.mock_cloudtrail_bucket_name
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

