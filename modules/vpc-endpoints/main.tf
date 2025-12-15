terraform {
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "~> 5.0"
        }
    }
}

# VPC Endpoint for DynamoDB (Gateway Type)
resource "aws_vpc_endpoint" "dynamodb" {
    vpc_id       = var.vpc_id
    service_name = "com.amazonaws.${var.region}.dynamodb"
    vpc_endpoint_type = "Gateway"

    # This automatically adds a route to the endpoint for DynamoDB traffic.
    route_table_ids = var.route_table_ids

    tags = merge(var.tags, {
        Name = "${var.env}-dynamodb-endpoint"
    })
}

# VPC Endpoint for S3 (Gateway Type - for CloudTrail logs)
resource "aws_vpc_endpoint" "s3" {
    vpc_id              = var.vpc_id
    service_name        = "com.amazonaws.${var.region}.s3"
    vpc_endpoint_type   = "Gateway"
    route_table_ids     = var.route_table_ids

    tags = merge(var.tags, {
        Name    = "${var.env}-s3-endpoint"
        Service = "S3"
    })
}

# S3 Endpoint Policy - Restrict to CloudTrail bucket
resource "aws_vpc_endpoint_policy" "s3" {
    vpc_endpoint_id = aws_vpc_endpoint.s3.id
    policy = jsonencode({
        Version = "2012-10-17",
        Statement = [
        {
            Effect  = "Allow"
            Action  = ["s3:*"]
            Principal = "*"
            Resource = [
                "arn:aws:s3:::${var.cloudtrail_bucket_name}",
                "arn:aws:s3:::${var.cloudtrail_bucket_name}/*"
            ]
        }
        ]
    })
}

# VPC Endpoint for Secrets Manager (Interface Type)
resource "aws_vpc_endpoint" "secretsmanager" {
    vpc_id              = var.vpc_id
    service_name        = "com.amazonaws.${var.region}.secretsmanager"
    vpc_endpoint_type   = "Interface"
    subnet_ids          = var.private_subnet_ids
    security_group_ids  = [aws_security_group.vpc_endpoints.id]
    private_dns_enabled = true

    tags = merge(var.tags, {
        Name    = "${var.env}-secretsmanager-endpoint"
        Service = "SecretsManager"
    })
}

# VPC Endpoint for Systems Manager (Interface Type)
resource "aws_vpc_endpoint" "ssm" {
    vpc_id              = var.vpc_id
    service_name        = "com.amazonaws.${var.region}.ssm"
    vpc_endpoint_type   = "Interface"
    subnet_ids          = var.private_subnet_ids
    security_group_ids  = [aws_security_group.vpc_endpoints.id]
    private_dns_enabled = true

    tags = merge(var.tags, {
        Name    = "${var.env}-ssm-endpoint"
        Service = "SystemsManager"
    })
}

# VPC Endpoint for EC2 Messages
resource "aws_vpc_endpoint" "ec2messages" {
    vpc_id              = var.vpc_id
    service_name        = "com.amazonaws.${var.region}.ec2messages"
    vpc_endpoint_type   = "Interface"
    subnet_ids          = var.private_subnet_ids
    security_group_ids  = [aws_security_group.vpc_endpoints.id]
    private_dns_enabled = true

    tags = merge(var.tags, {
        Name    = "${var.env}-ec2messages-endpoint"
        Service = "EC2Messages"
    })
}

# VPC Endpoint for SSM Messages
resource "aws_vpc_endpoint" "ssmmessages" {
    vpc_id              = var.vpc_id
    service_name        = "com.amazonaws.${var.region}.ssmmessages"
    vpc_endpoint_type   = "Interface"
    subnet_ids          = var.private_subnet_ids
    security_group_ids  = [aws_security_group.vpc_endpoints.id]
    private_dns_enabled = true

    tags = merge(var.tags, {
        Name    = "${var.env}-ssmmessages-endpoint"
        Service = "SSMMessages"
    })
}

# VPC Endpoint for STS (Security Token Service)
resource "aws_vpc_endpoint" "sts" {
    vpc_id              = var.vpc_id
    service_name        = "com.amazonaws.${var.region}.sts"
    vpc_endpoint_type   = "Interface"
    subnet_ids          = var.private_subnet_ids
    security_group_ids  = [aws_security_group.vpc_endpoints.id]
    private_dns_enabled = true

    tags = merge(var.tags, {
        Name    = "${var.env}-sts-endpoint"
        Service = "STS"
    })
}

# VPC Endpoint for CloudWatch Logs
resource "aws_vpc_endpoint" "logs" {
    vpc_id              = var.vpc_id
    service_name        = "com.amazonaws.${var.region}.logs"
    vpc_endpoint_type   = "Interface"
    subnet_ids          = var.private_subnet_ids
    security_group_ids  = [aws_security_group.vpc_endpoints.id]
    private_dns_enabled = true

    tags = merge(var.tags, {
        Name    = "${var.env}-logs-endpoint"
        Service = "CloudWatchLogs"
    })
}

# VPC Endpoint for KMS
resource "aws_vpc_endpoint" "kms" {
    vpc_id              = var.vpc_id
    service_name        = "com.amazonaws.${var.region}.kms"
    vpc_endpoint_type   = "Interface"
    subnet_ids          = var.private_subnet_ids
    security_group_ids  = [aws_security_group.vpc_endpoints.id]
    private_dns_enabled = true

    tags = merge(var.tags, {
        Name    = "${var.env}-kms-endpoint"
        Service = "KMS"
    })
}

# Security Group for VPC Endpoints
resource "aws_security_group" "vpc_endpoints" {
    name        = "${var.env}-vpc-endpoints-sg"
    description = "Security group for VPC Endpoints - allows HTTPS from VPC"
    vpc_id      = var.vpc_id

    ingress {
        description = "HTTPS from VPC"
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = [var.vpc_cidr]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = merge(var.tags, {
        Name = "${var.env}-vpc-endpoints-sg"
    })
}

# VPC Endpoint Policy for Secrets Manager - Restricted to VPC
resource "aws_vpc_endpoint_policy" "secretsmanager" {
    vpc_endpoint_id = aws_vpc_endpoint.secretsmanager.id
    policy = jsonencode({
        Version = "2012-10-17",
        Statement = [
        {
            Sid     = "AllowSecretsFromVPC"
            Effect  = "Allow"
            Action  = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
            Principal = { AWS = "*" }
            Resource = "arn:aws:secretsmanager:${var.region}:*:secret:${var.env}/*"
            Condition = {
                StringEquals = { "aws:SourceVpc" = var.vpc_id }
            }
        },
        {
            Sid     = "DenyExternalAccess"
            Effect  = "Deny"
            Action  = "secretsmanager:*"
            Principal = "*"
            Resource = "*"
            Condition = {
                StringNotEquals = { "aws:SourceVpc" = var.vpc_id }
            }
        }
        ]
    })
}

# VPC Endpoint Policies for Systems Manager endpoints
resource "aws_vpc_endpoint_policy" "ssm_core" {
    vpc_endpoint_id = aws_vpc_endpoint.ssm.id
    policy = jsonencode({
        Version = "2012-10-17",
        Statement = [
        {
            Effect  = "Allow"
            Action  = ["ssm:*"]
            Principal = "*"
            Resource = "*"
        }
        ]
    })
}

resource "aws_vpc_endpoint_policy" "ssm_messages" {
    vpc_endpoint_id = aws_vpc_endpoint.ssmmessages.id
    policy = jsonencode({
        Version = "2012-10-17",
        Statement = [
        {
            Effect  = "Allow"
            Action  = ["ssmmessages:CreateControlChannel", "ssmmessages:CreateDataChannel", "ssmmessages:OpenControlChannel", "ssmmessages:OpenDataChannel"]
            Principal = "*"
            Resource = "*"
        }
        ]
    })
}

resource "aws_vpc_endpoint_policy" "ec2_messages" {
    vpc_endpoint_id = aws_vpc_endpoint.ec2messages.id
    policy = jsonencode({
        Version = "2012-10-17",
        Statement = [
        {
            Effect  = "Allow"
            Action  = ["ec2messages:AcknowledgeMessage", "ec2messages:DeleteMessage", "ec2messages:FailMessage", "ec2messages:GetEndpoint", "ec2messages:GetMessages", "ec2messages:SendReply"]
            Principal = "*"
            Resource = "*"
        }
        ]
    })
}
