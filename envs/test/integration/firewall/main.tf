terraform {
    backend "local" {}
}

provider "aws" {
    region  = "eu-north-1"
}

data "aws_caller_identity" "current" {}

# INTEGRATION TESTING: Mock values for isolated module testing
# These values allow the firewall module to be tested independently
# without requiring VPC module to be deployed first
locals {
    # Mock VPC values - will be replaced by actual resources when deployed
    mock_vpc_id            = "vpc-mock-integration-test"
    mock_public_subnet_ids = ["subnet-mock-public-1a", "subnet-mock-public-1b"]
}

module "firewall" {
    source = "../../../../modules/firewall"

    env                 = "integration-test"
    region              = "eu-north-1"
    
    # Use mock values for isolated integration testing
    vpc_id              = local.mock_vpc_id
    public_subnet_ids   = local.mock_public_subnet_ids
}

output "firewall_id" {
    description = "The ID of the Network Firewall"
    value       = module.firewall.firewall_id
}

output "firewall_arn" {
    description = "The ARN of the Network Firewall"
    value       = module.firewall.firewall_arn
}

output "firewall_policy_id" {
    description = "The ID of the Firewall policy"
    value       = module.firewall.firewall_policy_id
}

output "firewall_status" {
    description = "The operational status of the Network Firewall"
    value       = module.firewall.firewall_status
}

