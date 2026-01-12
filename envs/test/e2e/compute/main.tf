terraform {
    backend "local" {}
}

provider "aws" {
    region  = "eu-north-1"
}

data "aws_caller_identity" "current" {}

# E2E TESTING: Read from local state files (sibling modules)
# VPC and Security must be deployed before compute
data "terraform_remote_state" "vpc" {
    backend = "local"
    config = {
        path = "../vpc/terraform.tfstate"
    }
}

data "terraform_remote_state" "security" {
    backend = "local"
    config = {
        path = "../security/terraform.tfstate"
    }
}

locals {
    vpc_state      = data.terraform_remote_state.vpc.outputs
    security_state = data.terraform_remote_state.security.outputs
}

module "compute" {
    source = "../../../../modules/compute"

    env                         = "e2e-test"
    region                      = "eu-north-1"
    bastion_allowed_cidr        = "10.0.1.0/24"
    instance_type               = "t3.micro"
    
    # Pass VPC configuration from local state
    vpc_id              = local.vpc_state.vpc_id
    public_subnet_ids   = local.vpc_state.public_subnet_ids
    private_subnet_ids  = local.vpc_state.private_subnet_ids
    
    # Pass security configuration from local state
    kms_key_arn                 = local.security_state.kms_key_arn
    app_instance_profile_name   = local.security_state.app_instance_profile_name
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
