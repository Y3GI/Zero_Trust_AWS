provider "aws" {
    profile = "default"
    region  = "eu-north-1"
}

# Get outputs from security module
data "terraform_remote_state" "security" {
    backend = "local"
    config = { path = "../security/terraform.tfstate" }
}

module "rbac_authorization" {
    source = "../../../modules/rbac-authorization"

    env = "dev"
}

output "bastion_policy_arn" {
    value = module.rbac_authorization.bastion_policy_arn
}

output "app_tier_policy_arn" {
    value = module.rbac_authorization.app_tier_policy_arn
}
