resource "aws_flow_log" "main" {
    iam_role_arn = var.flow_log_role_arn
    vpc_id = var.vpc_id
    traffic_type = "ALL"
}

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