variable "role_name" {
  description = "Name of the IAM role assumed by GitHub Actions."
  type        = string
}

variable "github_oidc_provider_arn" {
  description = "ARN of the shared GitHub OIDC provider."
  type        = string
}

variable "github_repository" {
  description = "GitHub repository in owner/name format."
  type        = string
}

variable "github_environment" {
  description = "GitHub Environment allowed to assume the role."
  type        = string
}

variable "ecr_repository_arn" {
  description = "ARN of the ECR repository that stores the task image."
  type        = string
}

variable "execution_role_arn" {
  description = "ARN of the ECS task execution role."
  type        = string
}

variable "task_role_arn" {
  description = "ARN of the ECS task application role."
  type        = string
}

variable "tags" {
  description = "Tags applied to created resources."
  type        = map(string)
  default     = {}
}
