terraform{
    # Bootstrap uses local state only
    # It creates the S3 bucket and DynamoDB table for other modules to use
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# ===============================================
# S3 BUCKET FOR TERRAFORM STATE
# ===============================================

resource "aws_s3_bucket" "terraform_state" {
    bucket        = "${var.env}-terraform-state-${random_id.trail_suffix.hex}"
    force_destroy = true # Only for Dev; remove for Prod
    tags          = var.tags
    
    # If bucket already exists, adopt it instead of creating
    lifecycle {
        ignore_changes = all
    }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
    bucket = aws_s3_bucket.terraform_state.id
    versioning_configuration {
        status = "Enabled"
    }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
    bucket = aws_s3_bucket.terraform_state.id

    rule {
        apply_server_side_encryption_by_default {
            sse_algorithm     = "aws:kms"
            kms_master_key_id = var.kms_key_id
        }
        bucket_key_enabled = true
    }
}

# ===============================================
# S3 BUCKET FOR CLOUDTRAIL
# ===============================================

# 1. S3 Bucket for Long-term Storage
resource "random_id" "trail_suffix" {
    byte_length = 4
}

resource "aws_s3_bucket" "cloudtrail_bucket" {
    bucket        = "${var.env}-ztna-audit-logs-${random_id.trail_suffix.hex}"
    force_destroy = true # Only for Dev; remove for Prod
    tags          = var.tags
    
    # If bucket already exists, adopt it instead of creating
    lifecycle {
        ignore_changes = all
    }
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