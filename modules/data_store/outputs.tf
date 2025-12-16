# DynamoDB Table Outputs
output "dynamodb_table_name" {
    description = "The name of the DynamoDB table"
    value       = aws_dynamodb_table.main.name
}

output "dynamodb_table_arn" {
    description = "The ARN of the DynamoDB table"
    value       = aws_dynamodb_table.main.arn
}

output "dynamodb_table_id" {
    description = "The ID of the DynamoDB table"
    value       = aws_dynamodb_table.main.id
}

