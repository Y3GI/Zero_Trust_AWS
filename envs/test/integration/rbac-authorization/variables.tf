variable "state_bucket" {
    description = "S3 bucket for terraform state (dynamically discovered)"
    type        = string
    default     = ""
}