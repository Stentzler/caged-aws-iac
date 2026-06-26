terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.tags
  }
}

data "aws_caller_identity" "current" {}

locals {
  tags = {
    Environment = "shared"
    ManagedBy   = "Terraform"
    Project     = var.project_name
  }

  lambda_deployments = {
    dev_check_availability = {
      environment   = "dev"
      repository    = "caged-check-availability-lambda"
      function_name = "${var.project_name}-dev-check-availability"
    }
    dev_download = {
      environment   = "dev"
      repository    = "caged-download-lambda"
      function_name = "${var.project_name}-dev-download"
    }
    dev_query = {
      environment   = "dev"
      repository    = "caged-query-lambda"
      function_name = "${var.project_name}-dev-query"
    }
    prod_check_availability = {
      environment   = "prod"
      repository    = "caged-check-availability-lambda"
      function_name = "${var.project_name}-prod-check-availability"
    }
    prod_download = {
      environment   = "prod"
      repository    = "caged-download-lambda"
      function_name = "${var.project_name}-prod-download"
    }
    prod_query = {
      environment   = "prod"
      repository    = "caged-query-lambda"
      function_name = "${var.project_name}-prod-query"
    }
  }

  ecs_task_deployments = {
    dev_processing_task = {
      environment        = "dev"
      repository         = "caged-processing-task"
      ecr_repository_arn = "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/${var.project_name}-dev-processing-task"
      execution_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-dev-processing-task-execution"
      task_role_arn      = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-dev-processing-task-task"
    }
    prod_processing_task = {
      environment        = "prod"
      repository         = "caged-processing-task"
      ecr_repository_arn = "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/${var.project_name}-prod-processing-task"
      execution_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-prod-processing-task-execution"
      task_role_arn      = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-prod-processing-task-task"
    }
  }
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]
  tags           = local.tags
}

module "github_actions_deploy_role" {
  for_each = local.lambda_deployments
  source   = "../../modules/github_actions_deploy_role"

  role_name                = "${var.project_name}-${each.value.environment}-${each.value.repository}-deploy"
  github_oidc_provider_arn = aws_iam_openid_connect_provider.github_actions.arn
  github_repository        = "${var.github_owner}/${each.value.repository}"
  github_environment       = each.value.environment
  lambda_function_arn      = "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:${each.value.function_name}"
  tags                     = merge(local.tags, { Environment = each.value.environment })
}

module "github_actions_ecs_deploy_role" {
  for_each = local.ecs_task_deployments
  source   = "../../modules/github_actions_ecs_deploy_role"

  role_name                = "${var.project_name}-${each.value.environment}-${each.value.repository}-deploy"
  github_oidc_provider_arn = aws_iam_openid_connect_provider.github_actions.arn
  github_repository        = "${var.github_owner}/${each.value.repository}"
  github_environment       = each.value.environment
  ecr_repository_arn       = each.value.ecr_repository_arn
  execution_role_arn       = each.value.execution_role_arn
  task_role_arn            = each.value.task_role_arn
  tags                     = merge(local.tags, { Environment = each.value.environment })
}

output "github_oidc_provider_arn" {
  description = "ARN of the account-wide GitHub Actions OIDC provider."
  value       = aws_iam_openid_connect_provider.github_actions.arn
}

output "deploy_role_arns" {
  description = "Deployment role ARNs keyed by environment and application repository."
  value = merge(
    {
      for name, deployment_role in module.github_actions_deploy_role :
      name => deployment_role.role_arn
    },
    {
      for name, deployment_role in module.github_actions_ecs_deploy_role :
      name => deployment_role.role_arn
    },
  )
}
