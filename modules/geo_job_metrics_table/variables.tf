variable "table_name" {
  description = "Name of the CAGED geo/job metrics table."
  type        = string
}

variable "tags" {
  description = "Tags applied to created resources."
  type        = map(string)
  default     = {}
}
