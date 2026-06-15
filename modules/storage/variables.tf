variable "bucket_name" {
  description = "Globally unique name for the downloaded files bucket."
  type        = string
}

variable "force_destroy" {
  description = "Allow Terraform to delete a non-empty development bucket."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to created resources."
  type        = map(string)
  default     = {}
}
