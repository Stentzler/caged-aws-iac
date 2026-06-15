variable "aws_region" {
  description = "AWS region containing the Lambda functions."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project prefix used in resource names and tags."
  type        = string
  default     = "caged"
}

variable "github_owner" {
  description = "GitHub organization or user that owns the Lambda repositories."
  type        = string
  default     = "Stentzler"
}
