terraform{
    backend "s3"{
        bucket = "terraform-state"
        key = "terraform.tfstate"
        region = var.region
        dynamodb_table = "terraform-state"

        tags = merge(
            var.tags,
            {
                Name = "${var.env}-s3"
            }
        )
    }
}

# S3 BUCKET FOR CLOUDTRAIL

# 1. S3 Bucket for Long-term Storage
resource "random_id" "trail_suffix" {
    byte_length = 4
}

resource "aws_s3_bucket" "cloudtrail_bucket" {
    bucket        = "${var.env}-ztna-audit-logs-${random_id.trail_suffix.hex}"
    force_destroy = true # Only for Dev; remove for Prod
    tags          = var.tags
}

# 2. Bucket Policy (Required for CloudTrail to write to S3)
resource "aws_s3_bucket_policy" "cloudtrail_bucket_policy" {
    bucket = aws_s3_bucket.cloudtrail_bucket.id
    policy = jsonencode({
        Version = "2012-10-17",
        Statement = [
        {
            Sid    = "AWSCloudTrailAclCheck",
            Effect = "Allow",
            Principal = { Service = "cloudtrail.amazonaws.com" },
            Action   = "s3:GetBucketAcl",
            Resource = aws_s3_bucket.cloudtrail_bucket.arn
        },
        {
            Sid    = "AWSCloudTrailWrite",
            Effect = "Allow",
            Principal = { Service = "cloudtrail.amazonaws.com" },
            Action   = "s3:PutObject",
            Resource = "${aws_s3_bucket.cloudtrail_bucket.arn}/AWSLogs/*",
            Condition = {
                StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" }
            }
        }
        ]
    })
}