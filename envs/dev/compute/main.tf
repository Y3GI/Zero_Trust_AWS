terraform {
    backend "s3" {}
}

provider "aws" {
    region  = "eu-north-1"
}

data "aws_caller_identity" "current" {}

# Try S3 backend first (may not have state yet), suppress errors and fall back to local
data "terraform_remote_state" "vpc_s3" {
    backend = "s3"
    config = {
        bucket         = "dev-terraform-state-${data.aws_caller_identity.current.account_id}"
        key            = "dev/vpc/terraform.tfstate"
        region         = "eu-north-1"
        encrypt        = true
        skip_credentials_validation = true
    }
}

data "terraform_remote_state" "security_s3" {
    backend = "s3"
    config = {
        bucket         = "dev-terraform-state-${data.aws_caller_identity.current.account_id}"
        key            = "dev/security/terraform.tfstate"
        region         = "eu-north-1"
        encrypt        = true
        skip_credentials_validation = true
    }
}

# Use S3 state directly
locals {
    vpc_state      = data.terraform_remote_state.vpc_s3.outputs
    security_state = data.terraform_remote_state.security_s3.outputs
}

module "compute" {
    source = "../../../modules/compute"

    env                         = "dev"
    region                      = "eu-north-1"
    bastion_allowed_cidr        = "10.0.1.0/24"
    instance_type               = "t3.micro"
    
    # Pass network configuration from remote state with fallback to local
    vpc_id              = try(local.vpc_state.vpc_id, "vpc-error")
    public_subnet_ids   = try(local.vpc_state.public_subnet_ids, [])
    private_subnet_ids  = try(local.vpc_state.private_subnet_ids, [])
    
    # Pass security configuration with fallback to local
    kms_key_arn                 = try(local.security_state.kms_key_arn, "arn:aws:kms:eu-north-1:000000000000:key/error")
    app_instance_profile_name   = try(local.security_state.app_instance_profile_name, "error")
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
