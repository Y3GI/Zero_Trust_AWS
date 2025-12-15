output "bastion_policy_arn" {
    description = "ARN of the bastion restricted access policy"
    value       = aws_iam_policy.bastion_restricted_access.arn
}

output "app_server_policy_arn" {
    description = "ARN of the app server restricted access policy"
    value       = aws_iam_policy.app_server_restricted_access.arn
}

output "database_policy_arn" {
    description = "ARN of the database restricted access policy"
    value       = aws_iam_policy.database_restricted_access.arn
}

output "enforce_tagging_policy_arn" {
    description = "ARN of the enforce tagging policy"
    value       = aws_iam_policy.enforce_tagging.arn
}
