output "table_name" {
  description = "Name of the CAGED geo/job metrics table."
  value       = aws_dynamodb_table.this.name
}

output "table_arn" {
  description = "ARN of the CAGED geo/job metrics table."
  value       = aws_dynamodb_table.this.arn
}
