terraform {
    backend "s3" {}
}

provider "aws" {
    region  = "eu-north-1"
}

data "aws_caller_identity" "current" {}

# Read from S3 backend
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
    security_state = data.terraform_remote_state.security_s3.outputs
}

module "secrets" {
    source = "../../../modules/secrets"

    env                     = "dev"
    region                  = "eu-north-1"
    kms_key_id              = try(local.security_state.kms_key_id, "arn:aws:kms:eu-north-1:000000000000:key/error")
    app_instance_role_arn   = try(local.security_state.app_instance_role_arn, "arn:aws:iam::000000000000:role/error")

    db_password             = var.db_password
    api_key_1               = var.api_key_1
    api_key_2               = var.api_key_2
    
    db_username             = "appuser"
    db_host                 = "localhost"
    db_port                 = 5432
    db_name                 = "ztna_db"
}

output "db_credentials_secret_arn" {
    value = module.secrets.db_credentials_secret_arn
}

output "api_keys_secret_arn" {
    value = module.secrets.api_keys_secret_arn
}
