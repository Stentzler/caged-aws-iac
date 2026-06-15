variable "function_name" {
  description = "Name of the Lambda function."
  type        = string
}

variable "description" {
  description = "Description of the Lambda function."
  type        = string
  default     = null
}

variable "handler" {
  description = "Lambda handler entry point."
  type        = string
  default     = "handler.lambda_handler"
}

variable "runtime" {
  description = "Lambda managed runtime."
  type        = string
  default     = "python3.14"
}

variable "architectures" {
  description = "Instruction set architecture for the function."
  type        = list(string)
  default     = ["arm64"]
}

variable "memory_size" {
  description = "Memory allocated to the function in MB."
  type        = number
  default     = 256
}

variable "timeout" {
  description = "Function timeout in seconds."
  type        = number
  default     = 30
}

variable "ephemeral_storage_size" {
  description = "Ephemeral /tmp storage allocated to the function in MB."
  type        = number
  default     = 512
}

variable "environment_variables" {
  description = "Environment variables exposed to the function."
  type        = map(string)
  default     = {}
}

variable "iam_policy_json" {
  description = "Least-privilege IAM policy for application AWS API calls."
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
