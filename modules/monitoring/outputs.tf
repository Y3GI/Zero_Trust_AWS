output "budget_id" {
    value = module.budget.budget_id
}

output "flow_log_group_name" {
    value = aws_cloudwatch_log_group.flow_log_group.name
}

output "cloudtrail_bucket_name" {
    value = aws_s3_bucket.cloudtrail_bucket.id
}