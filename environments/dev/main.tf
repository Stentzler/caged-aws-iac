# The top-level `terraform` block configures Terraform itself. It does not
terraform {
  required_version = ">= 1.6.0"

  # Providers are plugins that allow Terraform to communicate with external
  # systems or provide extra functionality. Each provider has a source address
  # and a version constraint.
  required_providers {
    archive = {
      source = "hashicorp/archive"
      version = "~> 2.7"
    }

    aws = {
      source = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# A `provider` block configures an installed provider. All AWS resources in
# this root module use this configuration unless another provider alias is
# explicitly supplied.
provider "aws" {
  # `var.aws_region` reads the input variable named `aws_region`, declared in
  # variables.tf and currently set to us-east-1 in terraform.tfvars.
  region = var.aws_region

  default_tags {
    # `local.tags` refers to the local value declared in the `locals` block
    # below. Terraform resolves references regardless of declaration order.
    tags = local.tags
  }
}

# A `data` block reads existing information instead of creating a resource.
# This data source asks AWS which account is currently authenticated.
# Its values are referenced as `data.aws_caller_identity.current.<attribute>`.
data "aws_caller_identity" "current" {}

# `locals` defines reusable values calculated inside this Terraform module.
# Unlike input variables, callers cannot directly supply local values.
locals {
  name_prefix = "${var.project_name}-${var.environment}"

  tags = {
    Environment = var.environment
    ManagedBy = "Terraform"
    Project   = var.project_name
  }
}

# A `module` block calls a reusable group of Terraform files. The name
# `storage` is local to this environment and lets us reference module outputs
# using expressions such as `module.storage.bucket_name`.
module "storage" {
  source = "../../modules/storage"
  bucket_name = "${local.name_prefix}-downloaded-files-${data.aws_caller_identity.current.account_id}"

  # `force_destroy=false` prevents Terraform from deleting a non-empty bucket.
  force_destroy = var.force_destroy_download_bucket

  # Passing the shared tags explicitly also makes the module reusable with a
  # different provider configuration that may not define default tags.
  tags = local.tags
}

# Instantiate the reusable DynamoDB registry module.
module "registry" {
  source = "../../modules/registry"

  # The module creates a table with this name and a `registry_id` partition key.
  table_name = var.registry_table_name
  tags       = local.tags
}

# `aws_iam_policy_document` is another data source. It builds and validates an
# IAM policy as JSON locally; it does not create an IAM policy in AWS by itself.
data "aws_iam_policy_document" "check_availability" {
  statement {
    # `sid` is an optional human-readable identifier for this statement.
    sid = "ReadRegistry"
    effect = "Allow"
    actions = ["dynamodb:GetItem"]
    resources = [module.registry.table_arn]
  }
}

module "check_availability_lambda" {
  source = "../../modules/lambda_function"

  function_name = "${local.name_prefix}-check-availability"
  description   = "Find Novo CAGED FTP files that are not in the download registry."

  # Lambda memory is measured in MB. AWS also allocates CPU proportionally to
  # memory, so this affects both capacity and price.
  memory_size = 256

  # Lambda timeout is measured in seconds. The FTP tree scan may take longer
  # than the default three-second Lambda timeout.
  timeout = 300

  # This map becomes environment variables available to the Python process.
  # Terraform stores these values in the Lambda function configuration.
  environment_variables = {
    ENVIRONMENT  = var.environment
    SOURCE_NAME  = "check-availability"
    FTP_HOST     = "ftp.mtps.gov.br"
    FTP_ROOT_DIR = "/pdet/microdados/NOVO CAGED"

    # Referencing a module output avoids duplicating the table name and ensures
    # the function configuration always matches the table Terraform created.
    REGISTRY_TABLE_NAME = module.registry.table_name
    REGISTRY_ID         = var.registry_id
    REGISTRY_SOURCE     = "caged_ftp"

    # These variables configure AWS Lambda Powertools logging behavior.
    POWERTOOLS_SERVICE_NAME = "check-availability"
    POWERTOOLS_LOG_LEVEL    = "INFO"
    POWERTOOLS_LOG_EVENT = "false"
  }

  iam_policy_json = data.aws_iam_policy_document.check_availability.json

  # Retention controls how long CloudWatch keeps this function's log events.
  log_retention_days = var.log_retention_days
  tags               = local.tags
}

# Construct the least-privilege IAM policy for the download Lambda. It needs
# both registry access and permission to upload objects into one S3 prefix.
data "aws_iam_policy_document" "download" {
  statement {
    sid    = "ReadAndUpdateRegistry"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:UpdateItem",
    ]
    resources = [module.registry.table_arn]
  }

  statement {
    sid    = "UploadDownloadedFiles"
    effect = "Allow"
    actions = [
      "s3:AbortMultipartUpload",
      "s3:PutObject",
    ]
    resources = ["${module.storage.bucket_arn}/raw/caged/*"]
  }
}

# Instantiate the same reusable Lambda module for the function that downloads
# one file. The Step Functions Map state invokes this function once per item.
module "download_lambda" {
  source = "../../modules/lambda_function"

  function_name = "${local.name_prefix}-download"
  description   = "Download one Novo CAGED FTP archive and upload it to S3."
  memory_size = 512
  timeout     = 900
  ephemeral_storage_size = 2048

  environment_variables = {
    S3_BUCKET_NAME      = module.storage.bucket_name
    REGISTRY_TABLE_NAME = module.registry.table_name
    REGISTRY_ID         = var.registry_id

    FTP_TIMEOUT_SECONDS     = "30"
    FTP_DOWNLOAD_BLOCK_SIZE = "65536"

    POWERTOOLS_SERVICE_NAME = "download"
    POWERTOOLS_LOG_LEVEL    = "INFO"
    POWERTOOLS_LOG_EVENT    = "false"
  }

  iam_policy_json    = data.aws_iam_policy_document.download.json
  log_retention_days = var.log_retention_days
  tags               = local.tags
}

# Instantiate the orchestration module. Internally it creates the Step
# Functions state machine, its IAM role and logs, plus EventBridge Scheduler.
module "download_workflow" {
  source = "../../modules/download_workflow"

  # This name identifies both the state machine and related scheduler resources.
  name = "${local.name_prefix}-download-process"

  # Passing Lambda ARNs gives the workflow module exact invocation targets and
  # lets it build a least-privilege Step Functions execution policy.
  check_availability_lambda_arn = module.check_availability_lambda.function_arn
  download_lambda_arn           = module.download_lambda.function_arn

  # These inputs control whether and when EventBridge Scheduler starts the
  # workflow. The schedule is initially disabled during bootstrap.
  schedule_enabled    = var.schedule_enabled
  schedule_expression = var.schedule_expression
  schedule_timezone   = var.schedule_timezone

  log_retention_days = var.log_retention_days
  tags               = local.tags
}

# Outputs expose useful values after `terraform apply`. They can be displayed
# with `terraform output` and consumed by other Terraform configurations.
output "download_bucket_name" {
  # Descriptions appear in generated documentation and Terraform tooling.
  description = "S3 bucket containing downloaded CAGED archives."

  # The output value is forwarded from the reusable storage module.
  value = module.storage.bucket_name
}

output "registry_table_name" {
  description = "DynamoDB downloaded-file registry table."
  value       = module.registry.table_name
}

output "check_availability_function_name" {
  description = "Availability Lambda name used by its deployment workflow."
  value       = module.check_availability_lambda.function_name
}

output "download_function_name" {
  description = "Download Lambda name used by its deployment workflow."
  value       = module.download_lambda.function_name
}

output "state_machine_arn" {
  # An ARN is AWS's globally unique identifier for a resource. This value is
  # useful for manually starting or inspecting state-machine executions.
  description = "ARN of the CAGED download process state machine."
  value       = module.download_workflow.state_machine_arn
}
