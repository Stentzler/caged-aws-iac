variable "name" {
  description = "Name shared by the state machine and scheduler resources."
  type        = string
}

variable "check_availability_lambda_arn" {
  description = "ARN of the availability Lambda."
  type        = string
}

variable "download_lambda_arn" {
  description = "ARN of the download Lambda."
  type        = string
}

variable "notify_slack_topic_arn" {
  description = "SNS topic ARN used to publish Slack notification events."
  type        = string
}

variable "notifier_slack_success_channel_id" {
  description = "Slack channel ID used for successful workflow notifications."
  type        = string
}

variable "notifier_slack_error_channel_id" {
  description = "Slack channel ID used for failed workflow notifications."
  type        = string
}

variable "processing_task_cluster_arn" {
  description = "ARN of the ECS cluster that runs the processing task."
  type        = string
}

variable "processing_task_definition_family" {
  description = "ECS task definition family used to run the latest processing task revision."
  type        = string
}

variable "processing_task_container_name" {
  description = "Name of the processing container in the ECS task definition."
  type        = string
}

variable "processing_task_execution_role_arn" {
  description = "ARN of the processing ECS task execution role."
  type        = string
}

variable "processing_task_role_arn" {
  description = "ARN of the processing ECS task application role."
  type        = string
}

variable "processing_task_subnet_ids" {
  description = "Subnet IDs used when Step Functions runs the processing Fargate task."
  type        = list(string)
}

variable "processing_task_security_group_ids" {
  description = "Security group IDs used when Step Functions runs the processing Fargate task."
  type        = list(string)
}

variable "processing_task_assign_public_ip" {
  description = "Whether the processing Fargate task receives a public IP."
  type        = bool
  default     = true
}

variable "schedule_enabled" {
  description = "Whether the EventBridge Scheduler schedule is enabled."
  type        = bool
  default     = false
}

variable "schedule_expression" {
  description = "EventBridge Scheduler expression."
  type        = string
}

variable "schedule_timezone" {
  description = "IANA timezone used by EventBridge Scheduler."
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention period."
  type        = number
  default     = 14
}

variable "tags" {
  description = "Tags applied to created resources."
  type        = map(string)
  default     = {}
}
