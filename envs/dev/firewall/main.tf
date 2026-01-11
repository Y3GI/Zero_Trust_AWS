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
        use_lockfile   = true
        skip_credentials_validation = true
    }
}

# Use S3 state directly
locals {
    vpc_state = data.terraform_remote_state.vpc_s3.outputs
}

module "firewall" {
    source = "../../../modules/firewall"

    env                 = "dev"
    region              = "eu-north-1"
    
    # Pass VPC configuration from remote state with fallback to local
    vpc_id              = try(local.vpc_state.vpc_id, "vpc-error")
    public_subnet_ids   = try(local.vpc_state.public_subnet_ids, [])
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
