provider "aws" {
    profile = "default"
    region  = "eu-north-1"
}

# Get the VPC and Security outputs
data "terraform_remote_state" "vpc" {
    backend = "local"
    config = {
        path = "../vpc/terraform.tfstate"
    }
}

data "terraform_remote_state" "security" {
    backend = "local"
    config = {
        path = "../security/terraform.tfstate"
    }
}

data "terraform_remote_state" "bootstrap" {
    backend = "local"
    config = {
        path = "../bootstrap/terraform.tfstate"
    }
}

module "monitoring" {
    source = "../../../modules/monitoring"

    env                 = "dev"
    region              = "eu-north-1"
    email               = "547283@student.fontys.nl"
    limit_amount        = 100.00
    vpc_id              = data.terraform_remote_state.vpc.outputs.vpc_id
    flow_log_role_arn   = data.terraform_remote_state.security.outputs.flow_log_role_arn
    cloudtrail_role_arn = data.terraform_remote_state.security.outputs.cloudtrail_role_arn
}

output "budget_id" {
    description = "The ID of the AWS Budget"
    value       = module.monitoring.budget_id
}

output "cloudtrail_id" {
    description = "The ID of the CloudTrail"
    value       = module.monitoring.cloudtrail_id
}

output "flow_logs_id" {
    description = "The ID of the VPC Flow Logs"
    value       = module.monitoring.flow_logs_id
}

output "cloudwatch_alarm_id" {
    description = "The ID of the CloudWatch alarm"
    value       = module.monitoring.cloudwatch_alarm_id
}

output "cloudwatch_log_group_name" {
    description = "The name of the VPC Flow Logs CloudWatch group"
    value       = module.monitoring.cloudwatch_log_group_name
}

output "cloudtrail_log_group_name" {
    description = "The name of the CloudTrail CloudWatch group"
    value       = module.monitoring.cloudtrail_log_group_name
}