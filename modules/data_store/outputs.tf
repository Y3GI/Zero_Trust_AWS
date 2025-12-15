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

# VPC Endpoint for DynamoDB Outputs
output "dynamodb_vpc_endpoint_id" {
    description = "The ID of the DynamoDB VPC endpoint"
    value       = aws_vpc_endpoint.dynamodb.id
}

output "dynamodb_vpc_endpoint_arn" {
    description = "The ARN of the DynamoDB VPC endpoint"
    value       = aws_vpc_endpoint.dynamodb.arn
}
