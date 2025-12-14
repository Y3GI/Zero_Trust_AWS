resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
    name = "/aws/vpc/flow-logs/${var.env}"
    retention_in_days = 30

    tags = merge(
        var.tags,
        {
            Name = "${var.env}-vpc-flow-logs"
        }
    )
}

resource "aws_flow_log" "main" {
    iam_role_arn = var.flow_log_role_arn
    log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn
    vpc_id = var.vpc_id
    traffic_type = "ALL"
}

resource "aws_cloudwatch_metric_alarm" "high_rejects" {
    alarm_name = "${var.env}-HIGH-vpc-rejects"
    comparison_operator = "GreaterThanThreshold"
    evaluation_periods = "1"
    metric_name = "RejectCount"
    namespace = "AWS/VPCFlowLogs"
    period = "300"
    statistic = "Sum"
    threshold = "50"
    alarm_description   = "Alert if significant traffic is being blocked by NACLs/SGs"

    dimensions = {
        VpcId = var.vpc_id
    }
}


