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

# 2. VPC Endpoint for DynamoDB (Gateway Type)
# This routes traffic from your VPC to DynamoDB privately, bypassing the NAT/Internet.
resource "aws_vpc_endpoint" "dynamodb" {
    vpc_id       = var.vpc_id
    service_name = "com.amazonaws.${var.region}.dynamodb"
    vpc_endpoint_type = "Gateway"

    # Attach to Route Tables (Private Subnets)s
    # This automatically adds a route to the endpoint for DynamoDB traffic.
    route_table_ids = var.route_table_ids

    tags = merge(var.tags, {
        Name = "${var.env}-dynamodb-endpoint"
    })
}