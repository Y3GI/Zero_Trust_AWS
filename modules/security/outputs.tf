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