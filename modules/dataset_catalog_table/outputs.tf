output "table_name" {
  description = "Name of the CAGED dataset catalog table."
  value       = aws_dynamodb_table.this.name
}

output "table_arn" {
  description = "ARN of the CAGED dataset catalog table."
  value       = aws_dynamodb_table.this.arn
}
