# Budget Outputs
output "budget_id" {
    description = "The ID of the AWS Budget"
    value       = aws_budgets_budget.monthly.id
}

# CloudWatch Log Group Outputs
output "cloudwatch_log_group_id" {
    description = "The ID of the CloudWatch log group for VPC Flow Logs"
    value       = aws_cloudwatch_log_group.vpc_flow_logs.id
}

output "cloudwatch_log_group_name" {
    description = "The name of the CloudWatch log group for VPC Flow Logs"
    value       = aws_cloudwatch_log_group.vpc_flow_logs.name
}

output "cloudwatch_log_group_arn" {
    description = "The ARN of the CloudWatch log group for VPC Flow Logs"
    value       = aws_cloudwatch_log_group.vpc_flow_logs.arn
}

# CloudTrail Log Group Outputs
output "cloudtrail_log_group_id" {
    description = "The ID of the CloudWatch log group for CloudTrail events"
    value       = aws_cloudwatch_logs_group.cloudtrail_events.id
}

output "cloudtrail_log_group_name" {
    description = "The name of the CloudWatch log group for CloudTrail events"
    value       = aws_cloudwatch_logs_group.cloudtrail_events.name
}

output "cloudtrail_log_group_arn" {
    description = "The ARN of the CloudWatch log group for CloudTrail events"
    value       = aws_cloudwatch_logs_group.cloudtrail_events.arn
}

# Flow Logs Outputs
output "flow_logs_id" {
    description = "The ID of the VPC Flow Logs configuration"
    value       = aws_flow_log.main.id
}

output "flow_logs_arn" {
    description = "The ARN of the VPC Flow Logs configuration"
    value       = aws_flow_log.main.arn
}

# CloudWatch Alarm Outputs
output "cloudwatch_alarm_id" {
    description = "The ID of the VPC rejects alarm"
    value       = aws_cloudwatch_metric_alarm.high_rejects.id
}

output "cloudwatch_alarm_arn" {
    description = "The ARN of the VPC rejects alarm"
    value       = aws_cloudwatch_metric_alarm.high_rejects.arn
}

# CloudTrail Outputs
output "cloudtrail_id" {
    description = "The ID of the CloudTrail"
    value       = aws_cloudtrail.main.id
}

output "cloudtrail_arn" {
    description = "The ARN of the CloudTrail"
    value       = aws_cloudtrail.main.arn
}
