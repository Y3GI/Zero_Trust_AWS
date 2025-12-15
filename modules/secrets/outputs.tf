output "db_credentials_secret_arn" {
    description = "ARN of the database credentials secret"
    value       = aws_secretsmanager_secret.db_credentials.arn
}

output "db_credentials_secret_name" {
    description = "Name of the database credentials secret"
    value       = aws_secretsmanager_secret.db_credentials.name
}

output "api_keys_secret_arn" {
    description = "ARN of the API keys secret"
    value       = aws_secretsmanager_secret.api_keys.arn
}

output "api_keys_secret_name" {
    description = "Name of the API keys secret"
    value       = aws_secretsmanager_secret.api_keys.name
}

output "secrets_rotation_enabled" {
    description = "Whether automatic rotation is enabled"
    value       = "30 days"
}
