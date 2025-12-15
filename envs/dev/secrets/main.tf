provider "aws" {
    profile = "default"
    region  = "eu-north-1"
}

# Get outputs from security module
data "terraform_remote_state" "security" {
    backend = "local"
    config = { path = "../security/terraform.tfstate" }
}

module "secrets" {
    source = "../../../modules/secrets"

    kms_key_id   = data.terraform_remote_state.security.outputs.kms_key_id
    app_role_arn = data.terraform_remote_state.security.outputs.app_instance_role_arn

    db_password  = var.db_password
    api_key_1    = var.api_key_1
    api_key_2    = var.api_key_2
    
    db_username  = "appuser"
    db_host      = "localhost"
    db_port      = 5432
    db_name      = "ztna_db"
}

output "db_credentials_secret_arn" {
    value = module.secrets.db_credentials_secret_arn
}

output "api_keys_secret_arn" {
    value = module.secrets.api_keys_secret_arn
}
