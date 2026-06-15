output "function_name" {
  description = "Name of the Lambda function."
  value       = aws_lambda_function.this.function_name
}

output "function_arn" {
  description = "ARN of the Lambda function."
  value       = aws_lambda_function.this.arn
}

output "alias_arn" {
  description = "ARN of the environment alias used to invoke the Lambda function."
  value       = aws_lambda_alias.this.arn
}

output "execution_role_arn" {
  description = "ARN of the Lambda execution role."
  value       = aws_iam_role.this.arn
}
