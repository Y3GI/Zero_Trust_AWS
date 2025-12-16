variable "region" {
    description = "AWS region"
    type        = string
    default     = "eu-north-1"
}

variable "env" {
    description = "Environment name"
    type        = string
    default     = "dev"
}

variable "vpc_cidr" {
    description = "The CIDR block of the VPC"
    type        = string
    default     = "10.0.0.0/16"
}

variable "vpc_id" {
    description = "VPC ID for VPC endpoints"
    type        = string
}

variable "private_rt_id" {
    description = "ID of private route table"
    type        = string
}

variable "public_rt_id" {
    description = "ID of public route table"
    type        = string
}

variable "private_subnet_ids" {
    description = "IDs of private subnets"
    type        = list(string)
}

variable "cloudtrail_bucket_name" {
    description = "Name of S3 bucket for CloudTrail logs"
    type        = string
}

variable "tags" {
    description = "Common tags for all resources"
    type        = map(string)
    default = {
        Environment = "dev"
        Project     = "ztna-aws-1"
        Owner       = "Boyan Stefanov"
    }
}
