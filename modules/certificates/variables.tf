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

variable "tags" {
    description = "Common tags for all resources"
    type        = map(string)
    default = {
        Environment = "dev"
        Project     = "ztna-aws-1"
        Owner       = "Boyan Stefanov"
    }
}
