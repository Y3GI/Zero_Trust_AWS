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

variable "vpc_id" {
    description = "The ID of the VPC"
    type        = string
    default     = module.vpc.vpc_id 
}

variable "vpc_cidr" {
    description = "The CIDR block of the VPC"
    type        = string
    default     = "10.0.0.0/16"
}

variable "private_subnet_ids" {
    description = "List of private subnet IDs for Interface endpoints"
    type        = list(string)
}

variable "route_table_ids" {
    description = "List of route table IDs for Gateway endpoints"
    type        = list(string)
    default = [ module.vpc.private_rt_id, module.vpc.public_rt_id ]
}

variable "cloudtrail_bucket_name" {
    description = "Name of the CloudTrail S3 bucket"
    type        = string
    default = module.security.cloudtrail_bucket_name
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
