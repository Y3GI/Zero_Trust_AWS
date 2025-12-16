terraform {
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = ">= 5.0"
        }
    }
}

# Check if log group already exists in AWS
data "aws_cloudwatch_log_group" "vpc_flow_logs_check" {
    name = "/aws/vpc/flow-logs/${var.env}"
}

# Automatically import existing log group if it exists
resource "terraform_data" "import_vpc_flow_logs" {
    triggers_replace = [data.aws_cloudwatch_log_group.vpc_flow_logs_check.name]

    provisioner "local-exec" {
        command = <<-EOT
            set +e
            if aws logs describe-log-groups --log-group-name-prefix "/aws/vpc/flow-logs/${var.env}" --region ${data.aws_cloudwatch_log_group.vpc_flow_logs_check.arn != "" ? var.region : "eu-north-1"} | grep -q '"logGroupName": "/aws/vpc/flow-logs/${var.env}"'; then
                # Log group exists, try to import it
                terraform import -no-color module.monitoring.aws_cloudwatch_log_group.vpc_flow_logs "/aws/vpc/flow-logs/${var.env}" 2>&1 | grep -v "already in state" || true
            fi
            set -e
        EOT
        interpreter = ["/bin/bash", "-c"]
        on_failure = continue
    }
}

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
    depends_on = [terraform_data.import_vpc_flow_logs]
    
    name = "/aws/vpc/flow-logs/${var.env}"
    retention_in_days = 30

    tags = merge(
        var.tags,
        {
            Name = "${var.env}-vpc-flow-logs"
        }
    )

    lifecycle {
        # If log group already exists, adopt it without recreating
        ignore_changes = [retention_in_days, tags]
    }
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


