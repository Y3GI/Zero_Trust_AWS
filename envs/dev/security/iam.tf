provider "aws" {
    profile = "default"
    region  = "eu-north-1"
}

module "iam" {
    source = "../../../modules/security"
}

output "flow_log_role_arn" {
    value = module.iam.flow_log_role_arn
}

output "cloudtrail_role_arn" {
    value = module.iam.cloudtrail_role_arn
}

output "app_instance_role_arn" {
    value = module.iam.app_instance_role_arn
}

output "app_instance_profile_arn" {
    value = module.iam.app_instance_profile_arn
}