terraform {
    backend "s3" {}
}

provider "aws" {

    region  = "eu-north-1"
}

module "iam" {
    source = "../../../modules/security"
}

# Application Instance Role Outputs
output "app_instance_role_arn" {
    value = module.iam.app_instance_role_arn
}

output "app_instance_role_name" {
    value = module.iam.app_instance_role_name
}

output "app_instance_profile_arn" {
    value = module.iam.app_instance_profile_arn
}

output "app_instance_profile_name" {
    value = module.iam.app_instance_profile_name
}

# VPC Flow Logs Role Outputs
output "flow_log_role_arn" {
    value = module.iam.flow_log_role_arn
}

output "flow_log_role_name" {
    value = module.iam.flow_log_role_name
}

# CloudTrail Role Outputs
output "cloudtrail_role_arn" {
    value = module.iam.cloudtrail_role_arn
}

output "cloudtrail_role_name" {
    value = module.iam.cloudtrail_role_name
}

# KMS Key Outputs
output "kms_key_arn" {
    value = module.iam.kms_key_arn
}

output "kms_key_id" {
    value = module.iam.kms_key_id
}

output "kms_key_alias" {
    value = module.iam.kms_key_alias
}