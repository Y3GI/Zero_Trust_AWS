# S3 Bucket for CloudTrail Outputs
output "cloudtrail_bucket_id" {
    description = "The ID of the S3 bucket for CloudTrail logs"
    value       = aws_s3_bucket.cloudtrail_bucket.id
}

output "cloudtrail_bucket_arn" {
    description = "The ARN of the S3 bucket for CloudTrail logs"
    value       = aws_s3_bucket.cloudtrail_bucket.arn
}

output "cloudtrail_bucket_name" {
    description = "The name of the S3 bucket for CloudTrail logs"
    value       = aws_s3_bucket.cloudtrail_bucket.bucket
}

# S3 Bucket Policy Outputs
output "cloudtrail_bucket_policy_id" {
    description = "The ID of the CloudTrail bucket policy"
    value       = aws_s3_bucket_policy.cloudtrail_bucket_policy.id
}
