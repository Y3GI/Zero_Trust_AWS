terraform {
    backend "s3" {}
}

provider "aws" {
    region  = "eu-north-1"
}

data "aws_caller_identity" "current" {}

# Read from S3 backend
data "terraform_remote_state" "bootstrap_s3" {
    backend = "s3"
    config = {
        bucket         = "dev-terraform-state-${data.aws_caller_identity.current.account_id}"
        key            = "dev/bootstrap/terraform.tfstate"
        region         = "eu-north-1"
        encrypt        = true
        use_lockfile   = true
        skip_credentials_validation = true
    }
}

data "terraform_remote_state" "vpc_s3" {
    backend = "s3"
    config = {
        bucket         = "dev-terraform-state-${data.aws_caller_identity.current.account_id}"
        key            = "dev/vpc/terraform.tfstate"
        region         = "eu-north-1"
        encrypt        = true
        use_lockfile   = true
        skip_credentials_validation = true
    }
}

data "terraform_remote_state" "security_s3" {
    backend = "s3"
    config = {
        bucket         = "dev-terraform-state-${data.aws_caller_identity.current.account_id}"
        key            = "dev/security/terraform.tfstate"
        region         = "eu-north-1"
        encrypt        = true
        use_lockfile   = true
        skip_credentials_validation = true
    }
}

# Use S3 state directly
locals {
    bootstrap_state = data.terraform_remote_state.bootstrap_s3.outputs
    vpc_state       = data.terraform_remote_state.vpc_s3.outputs
    security_state  = data.terraform_remote_state.security_s3.outputs
}

module "monitoring" {
    source = "../../../modules/monitoring"

    env                     = "dev"
    region                  = "eu-north-1"
    email                   = "547283@student.fontys.nl"
    limit_amount            = 100.00
    
    # Pass dependencies from remote state with fallback to local
    vpc_id                  = try(local.vpc_state.vpc_id, "vpc-error")
    flow_log_role_arn       = try(local.security_state.flow_log_role_arn, "arn:aws:iam::000000000000:role/error")
    cloudtrail_role_arn     = try(local.security_state.cloudtrail_role_arn, "arn:aws:iam::000000000000:role/error")
    cloudtrail_bucket_name  = try(local.bootstrap_state.cloudtrail_bucket_name, "bucket-error")
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