variable "name" {
  description = "Name of the private REST API."
  type        = string
}

variable "description" {
  description = "Description of the private REST API."
  type        = string
  default     = null
}

variable "stage_name" {
  description = "API Gateway stage name."
  type        = string
}

variable "version_path_part" {
  description = "Version path segment exposed by the API."
  type        = string
}

variable "resource_path_part" {
  description = "Resource path segment exposed below the version path."
  type        = string
}

variable "http_method" {
  description = "HTTP method exposed by the API resource."
  type        = string
  default     = "GET"
}

variable "lambda_function_name" {
  description = "Name of the Lambda function integrated with the API."
  type        = string
}

variable "lambda_alias_name" {
  description = "Lambda alias invoked by the API."
  type        = string
}

variable "lambda_alias_arn" {
  description = "ARN of the Lambda alias invoked by the API."
  type        = string
}

variable "vpc_id" {
  description = "VPC where the execute-api interface endpoint is created."
  type        = string
}

variable "vpc_cidr_block" {
  description = "CIDR block allowed to reach the execute-api VPC endpoint."
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs used by the execute-api interface endpoint."
  type        = list(string)
}

variable "region" {
  description = "AWS region where the API is deployed."
  type        = string
}

variable "partition" {
  description = "AWS partition, such as aws or aws-us-gov."
  type        = string
  default     = "aws"
}

variable "tags" {
  description = "Tags applied to created resources."
  type        = map(string)
  default     = {}
}
