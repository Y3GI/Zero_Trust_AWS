provider "aws" {
    profile = "default"
    region  = "eu-north-1"
}

# Get the VPC outputs from the vpc module
data "terraform_remote_state" "vpc" {
    backend = "local"
    config = {
        path = "../vpc/terraform.tfstate"
    }
}

# Get the Security module outputs
data "terraform_remote_state" "security" {
    backend = "local"
    config = {
        path = "../security/terraform.tfstate"
    }
}

module "compute" {
    source = "../../../modules/compute"

    env                         = "dev"
    region                      = "eu-north-1"
    vpc_id                      = data.terraform_remote_state.vpc.outputs.vpc_id
    public_subnet_id            = data.terraform_remote_state.vpc.outputs.public_subnet_ids
    private_subnet_id           = data.terraform_remote_state.vpc.outputs.private_subnet_ids
    app_instance_profile_name   = data.terraform_remote_state.security.outputs.app_instance_profile_name
    kms_key_arn                 = data.terraform_remote_state.security.outputs.kms_key_arn
    bastion_allowed_cidr        = "10.0.1.0/24"
    instance_type               = "t3.micro"
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
