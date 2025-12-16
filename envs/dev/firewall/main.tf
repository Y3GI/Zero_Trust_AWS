provider "aws" {
    profile = "default"
    region  = "eu-north-1"
}

# Get the VPC outputs
data "terraform_remote_state" "vpc" {
    backend = "local"
    config = {
        path = "../vpc/terraform.tfstate"
    }
}

module "firewall" {
    source = "../../../modules/firewall"

    env                 = "dev"
    region              = "eu-north-1"
    
    # Pass VPC configuration (use try() to handle destroyed dependencies during destroy)
    vpc_id              = try(data.terraform_remote_state.vpc.outputs.vpc_id, "vpc-destroyed")
    public_subnet_ids   = try(data.terraform_remote_state.vpc.outputs.public_subnet_ids, [])
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
