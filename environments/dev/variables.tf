variable "aws_region" {
  description = "AWS region for the development stack."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project prefix used in resource names."
  type        = string
  default     = "caged"
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "dev"
}

variable "registry_table_name" {
  description = "Name of the downloaded-file registry table."
  type        = string
  default     = "downloaded_files_registry"
}

variable "registry_id" {
  description = "Partition key of the CAGED FTP registry item."
  type        = string
  default     = "ftp_tree"
}

variable "process_audit_table_name" {
  description = "Name of the CAGED file processing audit table."
  type        = string
  default     = "caged_processes"
}

variable "processing_task_cpu" {
  description = "CPU units reserved for the processing ECS task."
  type        = number
  default     = 1024
}

variable "processing_task_memory" {
  description = "Memory in MiB reserved for the processing ECS task."
  type        = number
  default     = 2048
}

variable "processing_task_ephemeral_storage_size" {
  description = "Ephemeral storage in GiB for the processing ECS task."
  type        = number
  default     = 50
}

variable "processing_task_image_tag" {
  description = "Container image tag deployed to the processing task definition."
  type        = string
  default     = "bootstrap"
}

variable "schedule_enabled" {
  description = "Enable the daily Step Functions schedule after bootstrap is complete."
  type        = bool
  default     = false
}

variable "schedule_expression" {
  description = "Daily EventBridge Scheduler expression."
  type        = string
  default     = "cron(0 6 * * ? *)"
}

variable "schedule_timezone" {
  description = "IANA timezone for the daily schedule."
  type        = string
  default     = "America/Sao_Paulo"
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention period."
  type        = number
  default     = 14
}

variable "force_destroy_download_bucket" {
  description = "Allow deletion of a non-empty development download bucket."
  type        = bool
  default     = false
}
