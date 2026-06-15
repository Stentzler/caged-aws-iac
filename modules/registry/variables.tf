variable "table_name" {
  description = "Name of the downloaded-file registry table."
  type        = string
}

variable "tags" {
  description = "Tags applied to created resources."
  type        = map(string)
  default     = {}
}
