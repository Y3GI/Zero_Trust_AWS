terraform {
    backend "local" {}
}

provider "aws" {
    region  = "eu-north-1"
}

data "aws_caller_identity" "current" {}

# E2E TESTING: Read from local state files (sibling modules)
# Bootstrap, VPC, and Security must be deployed before monitoring
data "terraform_remote_state" "bootstrap" {
    backend = "local"
    config = {
        path = "../bootstrap/terraform.tfstate"
    }
}

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

locals {
    bootstrap_state = data.terraform_remote_state.bootstrap.outputs
    vpc_state       = data.terraform_remote_state.vpc.outputs
    security_state  = data.terraform_remote_state.security.outputs
}

module "monitoring" {
    source = "../../../../modules/monitoring"

    env                     = "e2e-test"
    region                  = "eu-north-1"
    email                   = "test@example.com"
    limit_amount            = 100.00
    
    # Pass dependencies from local state
    vpc_id                  = local.vpc_state.vpc_id
    flow_log_role_arn       = local.security_state.flow_log_role_arn
    cloudtrail_role_arn     = local.security_state.cloudtrail_role_arn
    cloudtrail_bucket_name  = local.bootstrap_state.cloudtrail_bucket_name
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