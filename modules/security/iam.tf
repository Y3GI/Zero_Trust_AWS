# 1. The IAM Role for Application Instances
resource "aws_iam_role" "app_instance_role" {
    name               = "${var.env}-ZT-App-Role"
    assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
    description        = "Least privilege role for Zero Trust application instances."

    tags = merge(
        var.tags,{
        Service     = "Compute"
    })
}

# 2. Policy for Secrets and Encryption (KMS and Secrets Manager)
resource "aws_iam_role_policy" "app_secrets_policy" {
    name   = "${var.env}-ZT-SecretsKMS-Policy"
    role = aws_iam_role.app_instance_role.id
    policy = jsonencode({
        Version = "2012-10-17",
        Statement = [
        {
            Sid      = "AccessSecretsAndKMS"
            Effect   = "Allow"
        # Grant read-only access to specific services
        Action = [
            "secretsmanager:GetSecretValue",
            "kms:Decrypt"
        ],
        # ZT principle: Restrict to specific ARNs (KMS keys and secrets)
        Resource = [
            "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:app/*",
            "arn:aws:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:key/*" # Should be restricted to specific KMS keys later
            ]
        },
        ],
    })
}

# 3. Policy for CloudWatch Logging (Required by all applications)
resource "aws_iam_role_policy" "app_logging_policy" {
    name   = "${var.env}-ZT-Logging-Policy"
    role  = aws_iam_role.app_instance_role.id
    policy = jsonencode({
        Version = "2012-10-17",
        Statement = [
        {
            Sid    = "WriteLogsToCloudWatch"
            Effect = "Allow"
            Action = [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
        Resource = "arn:aws:logs:*:*:log-group:/aws/ec2/${var.env}/*"
        },
        ],
    })
}

#-------------------------------------------------------------------------------
# Trust Policy: Trust the VPC Flow Logs service
data "aws_iam_policy_document" "flow_log_trust" {
    statement {
        actions = ["sts:AssumeRole"]
        principals {
            type        = "Service"
            identifiers = ["vpc-flow-logs.amazonaws.com"]
        }
    }
}

# The Role
resource "aws_iam_role" "vpc_flow_log_role" {
    name               = "${var.env}-ZT-FlowLog-Role"
    assume_role_policy = data.aws_iam_policy_document.flow_log_trust.json
    description        = "Role allowing VPC Flow Logs to write to CloudWatch."
    
    tags = merge(var.tags, { Service = "Monitoring" })
}

# The Policy (Permission to write logs)
resource "aws_iam_role_policy" "vpc_flow_log_policy" {
    name = "${var.env}-ZT-FlowLog-Policy"
    role = aws_iam_role.vpc_flow_log_role.id
    policy = jsonencode({
            Version = "2012-10-17",
            Statement = [{
                Action = [
                    "logs:CreateLogGroup",
                    "logs:CreateLogStream",
                    "logs:PutLogEvents",
                    "logs:DescribeLogGroups",
                    "logs:DescribeLogStreams"
                ],
            Effect   = "Allow",
            Resource = "*" # IAM is global, so we allow writing to any log group in this account
            }]
        })
}

#-------------------------------------------------------------------------------
# Trust Policy: Trust the CloudTrail service
data "aws_iam_policy_document" "cloudtrail_trust" {
    statement {
        actions = ["sts:AssumeRole"]
        principals {
            type        = "Service"
            identifiers = ["cloudtrail.amazonaws.com"]
        }
    }
}

# The Role
resource "aws_iam_role" "cloudtrail_role" {
    name               = "${var.env}-ZT-CloudTrail-Role"
    assume_role_policy = data.aws_iam_policy_document.cloudtrail_trust.json
    description        = "Role allowing CloudTrail to write to CloudWatch Logs."

    tags = merge(var.tags, { Service = "Monitoring" })
}

# The Policy
resource "aws_iam_role_policy" "cloudtrail_policy" {
    name = "${var.env}-ZT-CloudTrail-Policy"
    role = aws_iam_role.cloudtrail_role.id
    policy = jsonencode({
        Version = "2012-10-17",
        Statement = [{
            Action   = ["logs:CreateLogStream", "logs:PutLogEvents"],
            Effect   = "Allow",
            Resource = "arn:aws:logs:*:*:log-group:/aws/cloudtrail/${var.env}*" 
        }]
    })
}

#-------------------------------------------------------------------------------
# 4. Instance Profile (used to link the role to the EC2 instance)
resource "aws_iam_instance_profile" "app_instance_profile" {
    name = aws_iam_role.app_instance_role.name
    role = aws_iam_role.app_instance_role.name
}