terraform {
    backend "local" {}
}

provider "aws" {
    region  = "eu-north-1"
}

data "aws_caller_identity" "current" {}

# E2E TESTING: Read from local state files (sibling modules)
# VPC must be deployed before firewall
data "terraform_remote_state" "vpc" {
    backend = "local"
    config = {
        path = "../vpc/terraform.tfstate"
    }
}

locals {
    vpc_state = data.terraform_remote_state.vpc.outputs
}

module "firewall" {
    source = "../../../../modules/firewall"

    env                 = "e2e-test"
    region              = "eu-north-1"
    
    # Pass VPC configuration from local state
    vpc_id              = local.vpc_state.vpc_id
    public_subnet_ids   = local.vpc_state.public_subnet_ids
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
