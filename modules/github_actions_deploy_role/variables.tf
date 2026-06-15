variable "role_name" {
  description = "Name of the IAM role assumed by GitHub Actions."
  type        = string
}

variable "github_oidc_provider_arn" {
  description = "ARN of the GitHub Actions IAM OIDC provider."
  type        = string
}

variable "github_repository" {
  description = "GitHub repository in owner/name format."
  type        = string
}

variable "github_environment" {
  description = "GitHub Environment allowed to assume the deployment role."
  type        = string
}

variable "lambda_function_arn" {
  description = "ARN of the Lambda function this role may deploy."
  type        = string
}

variable "tags" {
  description = "Tags applied to the deployment role."
  type        = map(string)
  default     = {}
}
