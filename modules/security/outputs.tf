# Application Instance Role Outputs
output "app_instance_role_arn" {
    description = "ARN of the IAM role for application instances"
    value       = aws_iam_role.app_instance_role.arn
}

output "app_instance_role_name" {
    description = "Name of the IAM role for application instances"
    value       = aws_iam_role.app_instance_role.name
}

output "app_instance_profile_arn" {
    description = "ARN of the Instance Profile to attach to EC2 resources"
    value       = aws_iam_instance_profile.app_instance_profile.arn
}

output "app_instance_profile_name" {
    description = "The name of the Instance Profile to attach to EC2 resources"
    value       = aws_iam_instance_profile.app_instance_profile.name
}

# VPC Flow Logs Role Outputs
output "flow_log_role_arn" {
    description = "ARN of the IAM role for VPC Flow Logs"
    value       = aws_iam_role.vpc_flow_log_role.arn
}

output "flow_log_role_name" {
    description = "Name of the IAM role for VPC Flow Logs"
    value       = aws_iam_role.vpc_flow_log_role.name
}

# CloudTrail Role Outputs
output "cloudtrail_role_arn" {
    description = "ARN of the IAM role for CloudTrail"
    value       = aws_iam_role.cloudtrail_role.arn
}

output "cloudtrail_role_name" {
    description = "Name of the IAM role for CloudTrail"
    value       = aws_iam_role.cloudtrail_role.name
}

# KMS Key Outputs
output "kms_key_arn" {
    description = "ARN of the KMS key used for encrypting resources"
    value       = aws_kms_key.main.arn
}

output "kms_key_id" {
    description = "The ID of the KMS key"
    value       = aws_kms_key.main.id
}

output "kms_key_alias" {
    description = "The alias of the KMS key"
    value       = aws_kms_alias.main.name
}

output "kms_key_policy_id" {
    description = "The ID of the KMS key policy"
    value       = aws_kms_key_policy.main.id
}