output "role_arn" {
  description = "ARN configured as AWS_DEPLOY_ROLE_ARN in GitHub."
  value       = aws_iam_role.this.arn
}
