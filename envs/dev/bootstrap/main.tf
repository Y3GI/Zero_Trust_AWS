provider "aws" {

    region  = "eu-north-1"
}

module "bootstrap" {
    source = "../../../modules/bootstrap"

    env = "dev"
    region = "eu-north-1"
}

output "cloudtrail_bucket_id" {
    description = "The ID of the S3 bucket for CloudTrail logs"
    value       = module.bootstrap.cloudtrail_bucket_id
}

output "cloudtrail_bucket_name" {
    description = "The name of the S3 bucket for CloudTrail logs"
    value       = module.bootstrap.cloudtrail_bucket_name
}
