terraform {
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = ">= 5.0"
        }
    }
}

# Try to recover secrets scheduled for deletion
resource "terraform_data" "recover_secrets" {
    triggers_replace = [var.env]

    provisioner "local-exec" {
        command = <<-EOT
            set +e
            
            # Try to restore db_credentials if it exists in deleted state
            aws secretsmanager restore-secret --secret-id "${var.env}/app/db-credentials" --region eu-north-1 2>/dev/null || true
            
            # Try to restore api_keys if it exists in deleted state
            aws secretsmanager restore-secret --secret-id "${var.env}/app/api-keys" --region eu-north-1 2>/dev/null || true
            
            set -e
        EOT
        interpreter = ["/bin/bash", "-c"]
        on_failure = continue
    }
}

# Secrets Manager Secret for Database Credentials
resource "aws_secretsmanager_secret" "db_credentials" {
    depends_on = [terraform_data.recover_secrets]
    
    name                    = "${var.env}/app/db-credentials"
    description             = "Database credentials for ${var.env} application"
    recovery_window_in_days = 0  # Immediate deletion if recreated
    kms_key_id              = var.kms_key_id

    tags = merge(var.tags, {
        Name    = "${var.env}-db-secret"
        Service = "SecretsManager"
    })

    lifecycle {
        # Handle pre-existing secrets from previous deployments
        ignore_changes = [recovery_window_in_days, kms_key_id]
    }
}

# Secrets Manager Secret Version with actual credentials
resource "aws_secretsmanager_secret_version" "db_credentials" {
    secret_id = aws_secretsmanager_secret.db_credentials.id
    secret_string = jsonencode({
        username = var.db_username
        password = var.db_password
        host     = var.db_host
        port     = var.db_port
        database = var.db_name
    })
}

# Secrets Manager Secret for API Keys
resource "aws_secretsmanager_secret" "api_keys" {
    depends_on = [terraform_data.recover_secrets]
    
    name                    = "${var.env}/app/api-keys"
    description             = "API keys for ${var.env} application"
    recovery_window_in_days = 0  # Immediate deletion if recreated
    kms_key_id              = var.kms_key_id

    tags = merge(var.tags, {
        Name    = "${var.env}-api-keys-secret"
        Service = "SecretsManager"
    })

    lifecycle {
        # Handle pre-existing secrets from previous deployments
        ignore_changes = [recovery_window_in_days, kms_key_id]
    }
}

# Secrets Manager Secret Version for API Keys
resource "aws_secretsmanager_secret_version" "api_keys" {
    secret_id = aws_secretsmanager_secret.api_keys.id
    secret_string = jsonencode({
        api_key_v1 = var.api_key_1
        api_key_v2 = var.api_key_2
    })
}

# Rotation configuration for Database Credentials
# Note: Rotation requires a Lambda function to be set up separately
# This is commented out for now - uncomment and add rotation_lambda_arn when ready
# resource "aws_secretsmanager_secret_rotation" "db_credentials" {
#     secret_id           = aws_secretsmanager_secret.db_credentials.id
#     rotation_lambda_arn = var.rotation_lambda_arn  # Must be provided if rotation is enabled
#     rotation_rules {
#         automatically_after_days = 30
#     }
# }

# Resource Policy - Allow EC2 instances to read secrets
resource "aws_secretsmanager_secret_policy" "db_credentials" {
    secret_arn = aws_secretsmanager_secret.db_credentials.arn
    policy = jsonencode({
        Version = "2012-10-17",
        Statement = [
        {
            Sid    = "AllowAppRoleRead"
            Effect = "Allow"
            Principal = {
                AWS = var.app_instance_role_arn
            }
            Action = [
                "secretsmanager:GetSecretValue",
                "secretsmanager:DescribeSecret"
            ]
            Resource = "*"
        }
        ]
    })
}

resource "aws_secretsmanager_secret_policy" "api_keys" {
    secret_arn = aws_secretsmanager_secret.api_keys.arn
    policy = jsonencode({
        Version = "2012-10-17",
        Statement = [
        {
            Sid    = "AllowAppRoleRead"
            Effect = "Allow"
            Principal = {
                AWS = var.app_instance_role_arn
            }
            Action = [
                "secretsmanager:GetSecretValue",
                "secretsmanager:DescribeSecret"
            ]
            Resource = "*"
        }
        ]
    })
}
