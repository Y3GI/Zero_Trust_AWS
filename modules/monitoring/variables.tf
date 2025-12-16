# Base variables

variable "region" {
    description = "Availability zone for services"
    type = string
    default = "eu-north-1"
}

variable "tags"{
    description = "Tags for resources"
    type = map(string)
    default = {
        Environment = "dev"
        Project = "ztna-aws-1"
        Owner = "Boyan Stefanov"
    }
}

variable "env"{
    type = string
    default = "dev"
}

variable "vpc_id" {
    description = "VPC ID for CloudWatch Flow Logs"
    type        = string
}

variable "flow_log_role_arn" {
    description = "ARN of IAM role for VPC Flow Logs"
    type        = string
}

variable "cloudtrail_role_arn" {
    description = "ARN of IAM role for CloudTrail"
    type        = string
}

variable "cloudtrail_bucket_name" {
    description = "Name of S3 bucket for CloudTrail logs"
    type        = string
}

variable "email" {
    type = string
    default = "547283@student.fontys.nl"
}

# Budget monitoring

variable "limit_amount"{
    default = 100.00
}