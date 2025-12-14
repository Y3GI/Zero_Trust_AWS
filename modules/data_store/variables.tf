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
    description = "The VPC ID from the networking module"
    type        = string
    default = module.vpc.vpc_id
}

variable "kms_key_arn" {
    description = "The ARN of the KMS key for encrypting the DynamoDB table."
    type        = string
    default = module.security.kms_key_arn
}

variable "route_table_ids" {
    description = "The ID of the route table associated with the data store."
    type        = list(string)
    default = [ module.vpc.private_rt_id, module.vpc.public_rt_id ]

}
