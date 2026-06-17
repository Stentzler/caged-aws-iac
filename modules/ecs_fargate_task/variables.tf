variable "name" {
  description = "ECS task family name."
  type        = string
}

variable "cluster_name" {
  description = "Name of the ECS cluster that will run the task."
  type        = string
}

variable "container_name" {
  description = "Name of the container inside the task definition."
  type        = string
}

variable "image_uri" {
  description = "Full container image URI, including tag."
  type        = string
}

variable "cpu" {
  description = "Task CPU units."
  type        = number
}

variable "memory" {
  description = "Task memory in MiB."
  type        = number
}

variable "ephemeral_storage_size" {
  description = "Ephemeral task storage in GiB."
  type        = number
  default     = 21
}

variable "environment_variables" {
  description = "Environment variables injected into the container."
  type        = map(string)
  default     = {}
}

variable "task_role_policy_json" {
  description = "Inline IAM policy attached to the ECS task role."
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention period."
  type        = number
}

variable "tags" {
  description = "Tags applied to created resources."
  type        = map(string)
  default     = {}
}
