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

variable "kms_key_id" {
    description = "KMS key ID for encrypting secrets"
    type        = string
    default     = module.security.kms_key_id
}

variable "app_role_arn" {
    description = "ARN of the application IAM role (for accessing secrets)"
    type        = string
    default     = module.security.app_instance_role_arn
}

variable "db_username" {
    description = "Database username"
    type        = string
    sensitive   = true
    default     = "admin"
}

variable "db_password" {
    description = "Database password"
    type        = string
    sensitive   = true
    default     = "P@ssw0rd!"
}

variable "db_host" {
    description = "Database host"
    type        = string
    default     = "localhost"
}

variable "db_port" {
    description = "Database port"
    type        = number
    default     = 5432
}

variable "db_name" {
    description = "Database name"
    type        = string
    default     = "ztna_db"
}

variable "api_key_1" {
    description = "First API key"
    type        = string
    sensitive   = true
    default    = "default_api_key_1_value"
}

variable "api_key_2" {
    description = "Second API key (backup)"
    type        = string
    sensitive   = true
    default    = "default_api_key_2_value"
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
