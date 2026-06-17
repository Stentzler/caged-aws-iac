output "role_arn" {
  description = "ARN of the GitHub Actions ECS deployment role."
  value       = aws_iam_role.this.arn
}
