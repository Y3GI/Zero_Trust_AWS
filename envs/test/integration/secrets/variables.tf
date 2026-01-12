# Integration test variables - secrets module

variable "api_key_1" {
    description = "API Key 1 for external service integration."
    type        = string
    default     = "default_api_key_1_value"
}

variable "api_key_2" {
    description = "API Key 2 for external service integration."
    type        = string
    default     = "default_api_key_2_value"
}

variable "db_password" {
    description = "Password for the database user."
    type        = string
    sensitive   = true
    default     = "supersecretpassword"
}