# 1. IAM Role Trust Policy: Allows the EC2 Service to assume this role.
data "aws_iam_policy_document" "ec2_assume_role" {
    statement {
        actions = ["sts:AssumeRole"]
        principals {
            type        = "Service"
            identifiers = ["ec2.amazonaws.com"]
        }
    }
}

# 2. The IAM Role for Application Instances
resource "aws_iam_role" "app_instance_role" {
    name               = "${var.env}-ZT-App-Role"
    assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
    description        = "Least privilege role for Zero Trust application instances."

    tags = merge(
        var.tags,{
        Service     = "Compute"
    })
}

# 3. Policy for Secrets and Encryption (KMS and Secrets Manager)
resource "aws_iam_policy" "app_secrets_policy" {
    name   = "${var.env}-ZT-SecretsKMS-Policy"
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

# 4. Policy for CloudWatch Logging (Required by all applications)
resource "aws_iam_policy" "app_logging_policy" {
    name   = "${var.env}-ZT-Logging-Policy"
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

# 5. Attach Policies to the Role
resource "aws_iam_role_policy_attachment" "secrets_attach" {
    role       = aws_iam_role.app_instance_role.name
    policy_arn = aws_iam_policy.app_secrets_policy.arn
}

resource "aws_iam_role_policy_attachment" "logging_attach" {
    role       = aws_iam_role.app_instance_role.name
    policy_arn = aws_iam_policy.app_logging_policy.arn
}

# 6. Instance Profile (used to link the role to the EC2 instance)
resource "aws_iam_instance_profile" "app_instance_profile" {
    name = aws_iam_role.app_instance_role.name
    role = aws_iam_role.app_instance_role.name
}

# Output the profile name for use in the 'compute' module
output "app_instance_profile_name" {
    value = aws_iam_instance_profile.app_instance_profile.name
    description = "The name of the Instance Profile to attach to EC2 resources."
}