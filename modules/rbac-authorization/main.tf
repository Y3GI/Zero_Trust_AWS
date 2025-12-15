terraform {
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "~> 5.0"
        }
    }
}

# RBAC Policy Module: Attribute-Based Access Control (ABAC)
# This module creates additional authorization policies based on resource tags

# Policy for Bastion hosts - restricted access
resource "aws_iam_policy" "bastion_restricted_access" {
    name        = "${var.env}-bastion-restricted-access"
    description = "Restricted policy for bastion hosts - ABAC based on tags"
    
    policy = jsonencode({
        Version = "2012-10-17",
        Statement = [
            {
                Sid    = "AssumeRoleWithTag"
                Effect = "Allow"
                Action = [
                    "sts:AssumeRole"
                ]
                Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.env}-*"
                Condition = {
                    StringEquals = {
                        "iam:ResourceTag/Environment" = var.env
                        "iam:ResourceTag/Tier"        = "bastion"
                    }
                }
            },
            {
                Sid    = "AllowSessionManagerAccess"
                Effect = "Allow"
                Action = [
                    "ssm:StartSession",
                    "ssm:UpdateInstanceInformation"
                ]
                Resource = [
                    "arn:aws:ec2:*:${data.aws_caller_identity.current.account_id}:instance/*"
                ]
                Condition = {
                    StringEquals = {
                        "aws:ResourceTag/Tier" = "bastion"
                    }
                }
            },
            {
                Sid    = "DenyInternetAccess"
                Effect = "Deny"
                Action = [
                    "ec2:CreateInternetGateway",
                    "ec2:CreateNatGateway",
                    "ec2:AttachInternetGateway"
                ]
                Resource = "*"
            }
        ]
    })
}

# Policy for Application servers
resource "aws_iam_policy" "app_server_restricted_access" {
    name        = "${var.env}-app-server-restricted-access"
    description = "Restricted policy for application servers - ABAC based on tags"
    
    policy = jsonencode({
        Version = "2012-10-17",
        Statement = [
            {
                Sid    = "AccessApplicationSecrets"
                Effect = "Allow"
                Action = [
                    "secretsmanager:GetSecretValue",
                    "secretsmanager:DescribeSecret"
                ]
                Resource = "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:${var.env}/*"
                Condition = {
                    StringEquals = {
                        "aws:ResourceTag/Environment" = var.env
                        "aws:ResourceTag/Tier"        = "application"
                    }
                }
            },
            {
                Sid    = "AccessApplicationKMS"
                Effect = "Allow"
                Action = [
                    "kms:Decrypt",
                    "kms:DescribeKey",
                    "kms:GenerateDataKey"
                ]
                Resource = "arn:aws:kms:${var.region}:${data.aws_caller_identity.current.account_id}:key/*"
                Condition = {
                    StringEquals = {
                        "kms:ViaService" = [
                            "secretsmanager.${var.region}.amazonaws.com",
                            "dynamodb.${var.region}.amazonaws.com"
                        ]
                    }
                }
            },
            {
                Sid    = "AccessApplicationDatabase"
                Effect = "Allow"
                Action = [
                    "dynamodb:GetItem",
                    "dynamodb:Query",
                    "dynamodb:Scan",
                    "dynamodb:PutItem",
                    "dynamodb:UpdateItem"
                ]
                Resource = "arn:aws:dynamodb:${var.region}:${data.aws_caller_identity.current.account_id}:table/${var.env}-*"
                Condition = {
                    StringEquals = {
                        "aws:ResourceTag/Environment" = var.env
                        "aws:ResourceTag/Tier"        = "data"
                    }
                }
            },
            {
                Sid    = "CloudWatchLogsOnly"
                Effect = "Allow"
                Action = [
                    "logs:CreateLogGroup",
                    "logs:CreateLogStream",
                    "logs:PutLogEvents",
                    "logs:DescribeLogStreams"
                ]
                Resource = "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/ec2/${var.env}/*"
            },
            {
                Sid    = "DenyDataModification"
                Effect = "Deny"
                Action = [
                    "dynamodb:DeleteTable",
                    "dynamodb:DeleteItem"
                ]
                Resource = "arn:aws:dynamodb:${var.region}:${data.aws_caller_identity.current.account_id}:table/${var.env}-*-critical"
            }
        ]
    })
}

# Policy for Database access (future RDS/Aurora)
resource "aws_iam_policy" "database_restricted_access" {
    name        = "${var.env}-database-restricted-access"
    description = "Restricted policy for database tier - ABAC based on tags"
    
    policy = jsonencode({
        Version = "2012-10-17",
        Statement = [
            {
                Sid    = "DatabaseEncryptionOnly"
                Effect = "Allow"
                Action = [
                    "kms:Decrypt",
                    "kms:DescribeKey"
                ]
                Resource = "arn:aws:kms:${var.region}:${data.aws_caller_identity.current.account_id}:key/*"
                Condition = {
                    StringEquals = {
                        "aws:ResourceTag/Purpose" = "database-encryption"
                    }
                }
            },
            {
                Sid    = "NoPublicAccess"
                Effect = "Deny"
                Action = [
                    "rds-db:connect"
                ]
                Resource = "*"
                Condition = {
                    StringEquals = {
                        "aws:RequestedRegion" = "public"
                    }
                }
            }
        ]
    })
}

# Tagging policy - ensures all resources are properly tagged
resource "aws_iam_policy" "enforce_tagging" {
    name        = "${var.env}-enforce-tagging"
    description = "Policy to enforce proper resource tagging for ZTNA authorization"
    
    policy = jsonencode({
        Version = "2012-10-17",
        Statement = [
            {
                Sid    = "DenyUntaggedResources"
                Effect = "Deny"
                Action = [
                    "ec2:RunInstances",
                    "dynamodb:CreateTable",
                    "rds:CreateDBInstance",
                    "s3:CreateBucket"
                ]
                Resource = "*"
                Condition = {
                    StringLike = {
                        "aws:RequestTag/Environment" = ""
                        "aws:RequestTag/Tier"        = ""
                    }
                }
            }
        ]
    })
}

# Data sources
data "aws_caller_identity" "current" {}
