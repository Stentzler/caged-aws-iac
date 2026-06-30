resource "aws_security_group" "vpc_endpoint" {
  name        = "${var.name}-execute-api-vpce"
  description = "Private HTTPS access to the ${var.name} REST API."
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

resource "aws_vpc_endpoint" "execute_api" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.execute-api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-execute-api"
    },
  )
}

resource "aws_api_gateway_rest_api" "this" {
  name        = var.name
  description = var.description

  endpoint_configuration {
    types            = ["PRIVATE"]
    vpc_endpoint_ids = [aws_vpc_endpoint.execute_api.id]
  }

  tags = var.tags
}

data "aws_iam_policy_document" "api_policy" {
  statement {
    sid     = "AllowInvokeThroughVpcEndpoint"
    effect  = "Allow"
    actions = ["execute-api:Invoke"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    resources = ["${aws_api_gateway_rest_api.this.execution_arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceVpce"
      values   = [aws_vpc_endpoint.execute_api.id]
    }
  }
}

resource "aws_api_gateway_rest_api_policy" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  policy      = data.aws_iam_policy_document.api_policy.json
}

resource "aws_api_gateway_resource" "version" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = var.version_path_part
}

resource "aws_api_gateway_resource" "route" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.version.id
  path_part   = var.resource_path_part
}

resource "aws_api_gateway_method" "this" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.route.id
  http_method   = var.http_method
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.route.id
  http_method             = aws_api_gateway_method.this.http_method
  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = "arn:${var.partition}:apigateway:${var.region}:lambda:path/2015-03-31/functions/${var.lambda_alias_arn}/invocations"

  passthrough_behavior = "WHEN_NO_TEMPLATES"

  request_templates = {
    "application/json" = <<-VTL
      {
        "queryStringParameters": {
      #foreach($param in $input.params().querystring.keySet())
          "$util.escapeJavaScript($param)": "$util.escapeJavaScript($input.params().querystring.get($param))"#if($foreach.hasNext),#end
      #end
        }
      }
    VTL
  }
}

resource "aws_api_gateway_method_response" "this" {
  for_each = toset(["200", "400", "500", "503"])

  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.route.id
  http_method = aws_api_gateway_method.this.http_method
  status_code = each.value

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
    "method.response.header.Content-Type"                = true
  }
}

resource "aws_api_gateway_integration_response" "lambda" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.route.id
  http_method = aws_api_gateway_method.this.http_method
  status_code = aws_api_gateway_method_response.this["200"].status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
    "method.response.header.Content-Type"                = "'application/json'"
  }

  response_templates = {
    "application/json" = <<-VTL
      #set($context.responseOverride.status = $input.path('$.statusCode'))
      #set($body = $input.path('$.body'))
      #set($body = $body.replaceAll('"catalog_version"', '"catalogVersion"'))
      #set($body = $body.replaceAll('"location_type"', '"locationType"'))
      #set($body = $body.replaceAll('"location_code"', '"locationCode"'))
      #set($body = $body.replaceAll('"profession_code"', '"professionCode"'))
      #set($body = $body.replaceAll('"net_balance"', '"netBalance"'))
      #set($body = $body.replaceAll('"total_turnover"', '"totalTurnover"'))
      #set($body = $body.replaceAll('"avg_salary"', '"avgSalary"'))
      #set($body = $body.replaceAll('"salary_sum"', '"salarySum"'))
      #set($body = $body.replaceAll('"salary_count"', '"salaryCount"'))
      $body
    VTL
  }

  depends_on = [
    aws_api_gateway_integration.lambda,
    aws_api_gateway_method_response.this,
  ]
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "Allow${replace(title(var.name), "-", "")}ApiInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  qualifier     = var.lambda_alias_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*/${aws_api_gateway_method.this.http_method}${aws_api_gateway_resource.route.path}"
}

resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_rest_api_policy.this.policy,
      aws_api_gateway_resource.version.id,
      aws_api_gateway_resource.route.id,
      aws_api_gateway_method.this.id,
      aws_api_gateway_integration.lambda.id,
      aws_api_gateway_integration_response.lambda.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_rest_api_policy.this,
    aws_api_gateway_integration_response.lambda,
    aws_lambda_permission.api_gateway,
  ]
}

resource "aws_api_gateway_stage" "this" {
  deployment_id = aws_api_gateway_deployment.this.id
  rest_api_id   = aws_api_gateway_rest_api.this.id
  stage_name    = var.stage_name
  tags          = var.tags
}
