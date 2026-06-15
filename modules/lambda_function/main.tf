data "archive_file" "bootstrap" {
  type        = "zip"
  output_path = "${path.root}/.terraform/${var.function_name}-bootstrap.zip"

  source {
    content  = <<-PYTHON
      def lambda_handler(event, context):
          raise RuntimeError("Deploy application code through the Lambda repository CI workflow")
    PYTHON
    filename = "handler.py"
  }
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = "${var.function_name}-execution"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "basic_execution" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "application" {
  name   = "${var.function_name}-application"
  role   = aws_iam_role.this.id
  policy = var.iam_policy_json
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

resource "aws_lambda_function" "this" {
  function_name = var.function_name
  description   = var.description
  role          = aws_iam_role.this.arn
  handler       = var.handler
  runtime       = var.runtime
  architectures = var.architectures
  memory_size   = var.memory_size
  timeout       = var.timeout

  filename         = data.archive_file.bootstrap.output_path
  source_code_hash = data.archive_file.bootstrap.output_base64sha256
  publish          = true

  ephemeral_storage {
    size = var.ephemeral_storage_size
  }

  environment {
    variables = var.environment_variables
  }

  lifecycle {
    ignore_changes = [
      filename,
      source_code_hash,
    ]
  }

  depends_on = [
    aws_cloudwatch_log_group.this,
    aws_iam_role_policy_attachment.basic_execution,
    aws_iam_role_policy.application,
  ]

  tags = var.tags
}

resource "aws_lambda_alias" "this" {
  name             = var.alias_name
  description      = "${var.alias_name} environment release"
  function_name    = aws_lambda_function.this.function_name
  function_version = aws_lambda_function.this.version

  # CI publishes application versions and promotes the alias after bootstrap.
  lifecycle {
    ignore_changes = [
      function_version,
      routing_config,
    ]
  }
}
