data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.github_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repository}:environment:${var.github_environment}"]
    }
  }
}

resource "aws_iam_role" "this" {
  name                 = var.role_name
  description          = "Deploy ${var.lambda_function_arn} from ${var.github_repository}."
  assume_role_policy   = data.aws_iam_policy_document.assume_role.json
  max_session_duration = 3600
  tags                 = var.tags
}

data "aws_iam_policy_document" "deploy" {
  statement {
    effect = "Allow"
    actions = [
      "lambda:GetAlias",
      "lambda:GetFunction",
      "lambda:GetFunctionConfiguration",
      "lambda:PublishVersion",
      "lambda:UpdateAlias",
      "lambda:UpdateFunctionCode",
    ]
    resources = [
      var.lambda_function_arn,
      "${var.lambda_function_arn}:*",
    ]
  }
}

resource "aws_iam_role_policy" "deploy" {
  name   = "${var.role_name}-lambda-deploy"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.deploy.json
}
