# 1. DynamoDB Table (The Data Store)
resource "aws_dynamodb_table" "main" {
    name           = "${var.env}-ztna-table"
    billing_mode   = "PAY_PER_REQUEST" # Cost optimization (serverless model) [cite: 105]
    hash_key       = "LockID"          # Example key (often used for Terraform state locking too)

    attribute {
        name = "LockID"
        type = "S"
    }

    # Enable server-side encryption with your KMS key (Zero Trust requirement) [cite: 171]
    server_side_encryption {
        enabled     = true
        kms_key_arn = var.kms_key_arn
    }

    # Point-in-time recovery for backup/safety [cite: 104]
    point_in_time_recovery {
        enabled = true
    }

    tags = merge(var.tags, {
        Name    = "${var.env}-dynamo-table"
        Service = "DataStore"
    })
}