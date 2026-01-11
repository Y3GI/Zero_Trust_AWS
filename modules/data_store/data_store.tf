# DynamoDB table for Terraform state locking
resource "aws_dynamodb_table" "terraform_locks" {
    name           = "${var.env}-terraform-locks"
    billing_mode   = "PAY_PER_REQUEST"
    hash_key       = "LockID"

    attribute {
        name = "LockID"
        type = "S"
    }

    # Enable encryption with KMS key
    server_side_encryption {
        enabled     = true
        kms_key_arn = var.kms_key_arn
    }

    tags = merge(var.tags, {
        Name    = "${var.env}-terraform-locks"
        Service = "StateManagement"
    })
}

# DynamoDB table for application data
resource "aws_dynamodb_table" "main" {
    name           = "${var.env}-ztna-table"
    billing_mode   = "PAY_PER_REQUEST" # Cost optimization (serverless model)
    hash_key       = "LockID"

    attribute {
        name = "LockID"
        type = "S"
    }

    # Enable server-side encryption with your KMS key (Zero Trust requirement)
    server_side_encryption {
        enabled     = true
        kms_key_arn = var.kms_key_arn
    }

    # Point-in-time recovery for backup/safety
    point_in_time_recovery {
        enabled = true
    }

    tags = merge(var.tags, {
        Name    = "${var.env}-dynamo-table"
        Service = "DataStore"
    })
}