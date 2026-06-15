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
