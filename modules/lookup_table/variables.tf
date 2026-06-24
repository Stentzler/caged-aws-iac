variable "table_name" {
  description = "Name of the DynamoDB lookup table."
  type        = string
}

variable "partition_key" {
  description = "String partition key for the lookup table."
  type        = string
}

variable "sort_key" {
  description = "Optional string sort key for the lookup table."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to created resources."
  type        = map(string)
  default     = {}
}
