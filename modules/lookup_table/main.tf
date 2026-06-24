resource "aws_dynamodb_table" "this" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = var.partition_key
  range_key    = var.sort_key

  attribute {
    name = var.partition_key
    type = "S"
  }

  dynamic "attribute" {
    for_each = var.sort_key == null ? [] : [var.sort_key]

    content {
      name = attribute.value
      type = "S"
    }
  }

  point_in_time_recovery {
    enabled = false
  }

  server_side_encryption {
    enabled = true
  }

  tags = var.tags
}
