output "table_name" {
  description = "Name of the CAGED metric revisions table."
  value       = aws_dynamodb_table.this.name
}

output "table_arn" {
  description = "ARN of the CAGED metric revisions table."
  value       = aws_dynamodb_table.this.arn
}
