output "budget_id" {
    value = aws_budgets_budget.monthly.id
}

output "cloudwatch_log_group_id" {
    value = aws_cloudwatch_log_group.vpc_flow_logs.id
}

output "cloudtrail_log_group_id"{
    value = aws_cloudwatch_log_group.cloudtrail_events.id
}

output "flow_logs"{
    value = aws_flow_log.main.id
}

output "cloudwatch_alarm_id" {
    value = aws_cloudwatch_metric_alarm.high_rejects.id
}

output "cloudtrail_id"{
    value = aws_cloudtrail.main.id
}

output "flow_log_group_name"{
    value = aws_cloudwatch_log_group.vpc_flow_logs.name
}