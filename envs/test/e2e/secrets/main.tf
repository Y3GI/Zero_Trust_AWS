terraform {
    backend "local" {}
}

provider "aws" {
    region  = "eu-north-1"
}

data "aws_caller_identity" "current" {}

# E2E TESTING: Read from local state files (sibling modules)
# Security must be deployed before secrets
data "terraform_remote_state" "security" {
    backend = "local"
    config = {
        path = "../security/terraform.tfstate"
    }
}

locals {
    security_state = data.terraform_remote_state.security.outputs
}

module "secrets" {
    source = "../../../../modules/secrets"

    env                     = "e2e-test"
    region                  = "eu-north-1"
    
    # Pass security configuration from local state
    kms_key_id              = local.security_state.kms_key_id
    app_instance_role_arn   = local.security_state.app_instance_role_arn

    # Test credentials
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
