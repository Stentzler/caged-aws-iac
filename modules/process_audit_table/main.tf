resource "aws_dynamodb_table" "this" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "reference_month"
  range_key    = "process_id"

  attribute {
    name = "reference_month"
    type = "S"
  }

  attribute {
    name = "process_id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = false
  }

  server_side_encryption {
    enabled = true
  }

  tags = var.tags
}
