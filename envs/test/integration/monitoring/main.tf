terraform {
    backend "local" {}
}

provider "aws" {
    region  = "eu-north-1"
}

data "aws_caller_identity" "current" {}

# INTEGRATION TESTING: Mock values for isolated module testing
# These values allow the monitoring module to be tested independently
# without requiring Bootstrap, VPC, and Security modules to be deployed first
locals {
    # Mock Bootstrap values
    mock_cloudtrail_bucket_name = "mock-integration-test-cloudtrail-bucket"
    
    # Mock VPC values
    mock_vpc_id = "vpc-mock-integration-test"
    
    # Mock Security values (IAM role ARNs)
    mock_flow_log_role_arn   = "arn:aws:iam::000000000000:role/mock-integration-test-flow-log-role"
    mock_cloudtrail_role_arn = "arn:aws:iam::000000000000:role/mock-integration-test-cloudtrail-role"
}

module "monitoring" {
    source = "../../../../modules/monitoring"

    env                     = "integration-test"
    region                  = "eu-north-1"
    email                   = "test@example.com"
    limit_amount            = 100.00
    
    # Use mock values for isolated integration testing
    vpc_id                  = local.mock_vpc_id
    flow_log_role_arn       = local.mock_flow_log_role_arn
    cloudtrail_role_arn     = local.mock_cloudtrail_role_arn
    cloudtrail_bucket_name  = local.mock_cloudtrail_bucket_name
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
