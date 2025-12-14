# 1. The KMS Key
resource "aws_kms_key" "main" {
    description             = "KMS key for ${var.env} Zero Trust environment"
    deletion_window_in_days = 30
    enable_key_rotation     = true # Security Best Practice

    tags = merge(var.tags, {
        Name = "${var.env}-ztna-key"
    })
}

# 2. Alias (Friendly Name)
resource "aws_kms_alias" "main" {
    name          = "alias/${var.env}-ztna-key"
    target_key_id = aws_kms_key.main.key_id
}

# 3. Key Policy (Strict Access Control)
resource "aws_kms_key_policy" "main" {
    key_id = aws_kms_key.main.id
    policy = jsonencode({
        Version = "2012-10-17",
        Statement = [
        # 1. Allow Root User full control (Standard requirement to prevent locking yourself out)
        {
            Sid    = "Enable IAM User Permissions"
            Effect = "Allow"
            Principal = {
                AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
            },
            Action   = "kms:*"
            Resource = "*"
        },
        # 2. Allow the App Role to use the key for encryption/decryption
        {
            Sid    = "Allow App Role Use"
            Effect = "Allow"
            Principal = {
                AWS = aws_iam_role.app_instance_role.arn # references the role in iam.tf
            },
            Action = [
                "kms:Encrypt",
                "kms:Decrypt",
                "kms:ReEncrypt*",
                "kms:GenerateDataKey*",
                "kms:DescribeKey"
            ],
            Resource = "*"
        }
        ]
    })
}