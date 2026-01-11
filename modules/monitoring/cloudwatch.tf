terraform {
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = ">= 5.0"
        }
    }
}

# Check if log group already exists
data "aws_cloudwatch_log_groups" "vpc_flow_logs_check" {
    log_group_name_prefix = "/aws/vpc/flow-logs/${var.env}"
}

locals {
    vpc_flow_logs_exists = length(data.aws_cloudwatch_log_groups.vpc_flow_logs_check.arns) > 0
}

# Create CloudWatch log group only if it doesn't exist
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
    count = local.vpc_flow_logs_exists ? 0 : 1
    
    name              = "/aws/vpc/flow-logs/${var.env}"
    retention_in_days = 30
    skip_destroy      = false

    tags = merge(
        var.tags,
        {
            Name = "${var.env}-vpc-flow-logs"
        }
    )
}

# Data source to get the log group (either existing or newly created)
data "aws_cloudwatch_log_group" "vpc_flow_logs" {
    depends_on = [aws_cloudwatch_log_group.vpc_flow_logs]
    name       = "/aws/vpc/flow-logs/${var.env}"
}

resource "aws_flow_log" "main" {
    iam_role_arn    = var.flow_log_role_arn
    log_destination = data.aws_cloudwatch_log_group.vpc_flow_logs.arn
    vpc_id          = var.vpc_id
    traffic_type    = "ALL"
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


