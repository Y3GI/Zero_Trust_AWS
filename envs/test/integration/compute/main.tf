terraform {
    backend "local" {}
}

provider "aws" {
    region  = "eu-north-1"
}

data "aws_caller_identity" "current" {}

# INTEGRATION TESTING: Mock values for isolated module testing
# These values allow the compute module to be tested independently
# without requiring VPC and Security modules to be deployed first
locals {
    # Mock VPC values
    mock_vpc_id             = "vpc-mock-integration-test"
    mock_public_subnet_ids  = ["subnet-mock-public-1a", "subnet-mock-public-1b"]
    mock_private_subnet_ids = ["subnet-mock-private-1a", "subnet-mock-private-1b"]
    
    # Mock Security values
    mock_kms_key_arn              = "arn:aws:kms:eu-north-1:000000000000:key/mock-integration-test-key"
    mock_instance_profile_name    = "mock-integration-test-instance-profile"
}

module "compute" {
    source = "../../../../modules/compute"

    env                         = "integration-test"
    region                      = "eu-north-1"
    bastion_allowed_cidr        = "10.0.1.0/24"
    instance_type               = "t3.micro"
    
    # Use mock VPC values for isolated testing
    vpc_id              = local.mock_vpc_id
    public_subnet_ids   = local.mock_public_subnet_ids
    private_subnet_ids  = local.mock_private_subnet_ids
    
    # Use mock security values for isolated testing
    kms_key_arn                 = local.mock_kms_key_arn
    app_instance_profile_name   = local.mock_instance_profile_name
}


output "bastion_instance_id" {
    description = "The ID of the Bastion host instance"
    value       = module.compute.bastion_instance_id
}

output "bastion_public_ip" {
    description = "The public IP of the Bastion host"
    value       = module.compute.bastion_public_ip
}

output "app_server_instance_id" {
    description = "The ID of the Application server instance"
    value       = module.compute.app_server_instance_id
}

output "app_server_private_ip" {
    description = "The private IP of the Application server"
    value       = module.compute.app_server_private_ip
}

output "bastion_security_group_id" {
    description = "The ID of the Bastion security group"
    value       = module.compute.bastion_security_group_id
}

