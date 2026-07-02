data "aws_iam_policy_document" "state_machine_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
  }
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_iam_policy_document" "state_machine" {
  statement {
    effect = "Allow"
    actions = [
      "lambda:InvokeFunction",
    ]
    resources = [
      var.check_availability_lambda_arn,
      var.download_lambda_arn,
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogDelivery",
      "logs:GetLogDelivery",
      "logs:UpdateLogDelivery",
      "logs:DeleteLogDelivery",
      "logs:ListLogDeliveries",
      "logs:PutResourcePolicy",
      "logs:DescribeResourcePolicies",
      "logs:DescribeLogGroups",
    ]
    resources = ["*"]
  }

  statement {
    effect  = "Allow"
    actions = ["ecs:RunTask"]
    resources = [
      "arn:aws:ecs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:task-definition/${var.processing_task_definition_family}:*",
    ]

    condition {
      test     = "ArnEquals"
      variable = "ecs:cluster"
      values   = [var.processing_task_cluster_arn]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "ecs:DescribeTasks",
      "ecs:StopTask",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "events:DescribeRule",
      "events:PutRule",
      "events:PutTargets",
    ]
    resources = [
      "arn:aws:events:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:rule/StepFunctionsGetEventsForECSTaskRule",
    ]
  }

  statement {
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [var.notify_slack_topic_arn]
  }

  statement {
    effect  = "Allow"
    actions = ["iam:PassRole"]
    resources = [
      var.processing_task_execution_role_arn,
      var.processing_task_role_arn,
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "state_machine" {
  name               = "${var.name}-state-machine"
  assume_role_policy = data.aws_iam_policy_document.state_machine_assume_role.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "state_machine" {
  name   = "${var.name}-state-machine"
  role   = aws_iam_role.state_machine.id
  policy = data.aws_iam_policy_document.state_machine.json
}

resource "aws_cloudwatch_log_group" "state_machine" {
  name              = "/aws/vendedlogs/states/${var.name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

resource "aws_sfn_state_machine" "this" {
  name     = var.name
  role_arn = aws_iam_role.state_machine.arn
  type     = "STANDARD"

  definition = jsonencode({
    Comment = "Check for and sequentially download new Novo CAGED files"
    StartAt = "CheckAvailability"
    States = {
      CheckAvailability = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = var.check_availability_lambda_arn
          "Payload.$"  = "$"
        }
        OutputPath = "$.Payload"
        Retry = [{
          ErrorEquals = [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException",
            "Lambda.TooManyRequestsException",
          ]
          IntervalSeconds = 2
          MaxAttempts     = 3
          BackoffRate     = 2
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"]
          ResultPath  = "$.error"
          Next        = "BuildWorkflowFailedNotification"
        }]
        Next = "HasNewFiles"
      }
      HasNewFiles = {
        Type = "Choice"
        Choices = [{
          Variable  = "$.new_files[0]"
          IsPresent = true
          Next      = "NotifyNewFilesFound"
        }]
        Default = "NoNewFiles"
      }
      NotifyNewFilesFound = {
        Type     = "Task"
        Resource = "arn:aws:states:::sns:publish"
        Parameters = {
          TopicArn = var.notify_slack_topic_arn
          Message = jsonencode({
            action  = "notify-slack"
            channel = var.notifier_slack_success_channel_id
            message = "New CAGED files found, starting download."
          })
        }
        ResultPath = null
        Next       = "DownloadFiles"
      }
      NoNewFiles = {
        Type = "Pass"
        Parameters = {
          status = "NO_NEW_FILES"
          files  = []
        }
        End = true
      }

      # This Map state is where the array returned by the availability Lambda is
      # split into individual download jobs. For example, given this input:
      #
      # {
      #   "new_files": [
      #     { "filename": "file-a.7z", "s3_key": "..." },
      #     { "filename": "file-b.7z", "s3_key": "..." }
      #   ]
      # }
      #
      # Step Functions runs the nested DownloadFile state twice: once with the
      # file-a object as its input and once with the file-b object as its input.
      DownloadFiles = {
        # `Map` is the Step Functions state type for iterating over an array.
        Type = "Map"

        # `ItemsPath` selects the array to iterate over from the Map state's
        # input. The `$` symbol represents the current state's complete input,
        # so `$.new_files` means the value of its `new_files` property.
        ItemsPath = "$.new_files"

        # Only one iteration may run at a time. The Map still invokes the Lambda
        # once for every item, but it waits for one download to finish before
        # starting the next item. Increasing this value would allow parallel
        # downloads.
        MaxConcurrency = 1

        # `ItemProcessor` defines the small state machine executed separately
        # for every object selected by ItemsPath.
        ItemProcessor = {
          ProcessorConfig = {
            # INLINE means each iteration runs inside the parent execution. This
            # is suitable here because the availability Lambda returns at most
            # 12 files, well below the scale that requires Distributed Map.
            Mode = "INLINE"
          }

          # Every iteration begins at the nested state named DownloadFile.
          StartAt = "DownloadFile"
          States = {
            DownloadFile = {
              # A Task state performs work through an AWS service integration.
              Type = "Task"

              # This optimized integration synchronously invokes Lambda and
              # waits for the invocation result before completing the task.
              Resource = "arn:aws:states:::lambda:invoke"
              Parameters = {
                # Terraform replaces this variable reference with the ARN of the
                # download Lambda created by the parent environment module.
                FunctionName = var.download_lambda_arn

                # Inside a Map iteration, `$` is the current array item rather
                # than the original full workflow input. The `.$` suffix tells
                # Step Functions to evaluate `$` as a JSONPath expression.
                # Therefore each new_files object is passed directly as the
                # event received by one download Lambda invocation.
                "Payload.$" = "$"
              }

              # The Lambda integration wraps the function response in metadata
              # such as StatusCode and Payload. OutputPath keeps only Payload,
              # which is the dictionary returned by the download Lambda.
              OutputPath = "$.Payload"
              Retry = [{
                ErrorEquals = [
                  "Lambda.ServiceException",
                  "Lambda.AWSLambdaException",
                  "Lambda.SdkClientException",
                  "Lambda.TooManyRequestsException",
                  "States.TaskFailed",
                ]
                IntervalSeconds = 2
                MaxAttempts     = 3
                BackoffRate     = 2
              }]

              # End this individual Map iteration after its Lambda invocation.
              End = true
            }
          }
        }

        # After every iteration succeeds, a Map state produces an array of all
        # iteration outputs in the same order as the input items. ResultPath
        # stores that collected result under `files` while preserving the rest
        # of the current workflow input.
        ResultPath = "$.files"

        # Continue only after all selected files have completed successfully.
        Next = "DownloadsCompleted"
        Catch = [{
          ErrorEquals = ["States.ALL"]
          ResultPath  = "$.error"
          Next        = "BuildWorkflowFailedNotification"
        }]
      }
      DownloadsCompleted = {
        Type = "Pass"
        Parameters = {
          status = "COMPLETED"

          # The `.$` suffix again means evaluate a JSONPath. This copies the
          # collected Map results into the workflow's final `files` property.
          "files.$" = "$.files"
        }
        Next = "BuildDownloadsCompletedNotification"
      }
      BuildDownloadsCompletedNotification = {
        Type = "Pass"
        Parameters = {
          action  = "notify-slack"
          channel = var.notifier_slack_success_channel_id
          "message.$" = join("", [
            "States.Format(",
            "'All files downloaded successfully, starting processing task. Files: {}', ",
            "States.JsonToString($.files)",
            ")",
          ])
        }
        ResultPath = "$.notification"
        Next       = "NotifyDownloadsCompleted"
      }
      NotifyDownloadsCompleted = {
        Type     = "Task"
        Resource = "arn:aws:states:::sns:publish"
        Parameters = {
          TopicArn    = var.notify_slack_topic_arn
          "Message.$" = "States.JsonToString($.notification)"
        }
        ResultPath = null
        Next       = "PrepareProcessingInput"
      }
      PrepareProcessingInput = {
        Type = "Pass"
        Parameters = {
          "status.$" = "$.status"
          "files.$"  = "$.files"
        }
        Next = "RunProcessingTask"
      }
      RunProcessingTask = {
        Type     = "Task"
        Resource = "arn:aws:states:::ecs:runTask.sync"
        Parameters = {
          LaunchType     = "FARGATE"
          Cluster        = var.processing_task_cluster_arn
          TaskDefinition = var.processing_task_definition_family
          NetworkConfiguration = {
            AwsvpcConfiguration = {
              Subnets        = var.processing_task_subnet_ids
              SecurityGroups = var.processing_task_security_group_ids
              AssignPublicIp = var.processing_task_assign_public_ip ? "ENABLED" : "DISABLED"
            }
          }
          Overrides = {
            ContainerOverrides = [{
              Name = var.processing_task_container_name
              Environment = [{
                Name      = "PROCESSING_JOB_JSON"
                "Value.$" = "States.JsonToString($)"
              }]
            }]
          }
        }
        ResultPath = "$.processing_task"
        Catch = [{
          ErrorEquals = ["States.ALL"]
          ResultPath  = "$.error"
          Next        = "BuildWorkflowFailedNotification"
        }]
        Next = "NotifyProcessingCompleted"
      }
      NotifyProcessingCompleted = {
        Type     = "Task"
        Resource = "arn:aws:states:::sns:publish"
        Parameters = {
          TopicArn = var.notify_slack_topic_arn
          Message = jsonencode({
            action  = "notify-slack"
            channel = var.notifier_slack_success_channel_id
            message = "CAGED processing task completed successfully."
          })
        }
        ResultPath = null
        End        = true
      }
      BuildWorkflowFailedNotification = {
        Type = "Pass"
        Parameters = {
          action  = "notify-slack"
          channel = var.notifier_slack_error_channel_id
          "message.$" = join("", [
            "States.Format(",
            "'CAGED workflow failed. Error: {}. Cause: {}', ",
            "$.error.Error, ",
            "$.error.Cause",
            ")",
          ])
        }
        ResultPath = "$.notification"
        Next       = "NotifyWorkflowFailed"
      }
      NotifyWorkflowFailed = {
        Type     = "Task"
        Resource = "arn:aws:states:::sns:publish"
        Parameters = {
          TopicArn    = var.notify_slack_topic_arn
          "Message.$" = "States.JsonToString($.notification)"
        }
        ResultPath = null
        Next       = "WorkflowFailed"
      }
      WorkflowFailed = {
        Type  = "Fail"
        Error = "CagedWorkflowFailed"
        Cause = "CAGED workflow failed. Error details were sent to Slack."
      }
    }
  })

  logging_configuration {
    include_execution_data = true
    level                  = "ERROR"
    log_destination        = "${aws_cloudwatch_log_group.state_machine.arn}:*"
  }

  depends_on = [aws_iam_role_policy.state_machine]
  tags       = var.tags
}

data "aws_iam_policy_document" "scheduler_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "scheduler" {
  statement {
    effect    = "Allow"
    actions   = ["states:StartExecution"]
    resources = [aws_sfn_state_machine.this.arn]
  }
}

resource "aws_iam_role" "scheduler" {
  name               = "${var.name}-scheduler"
  assume_role_policy = data.aws_iam_policy_document.scheduler_assume_role.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "scheduler" {
  name   = "${var.name}-scheduler"
  role   = aws_iam_role.scheduler.id
  policy = data.aws_iam_policy_document.scheduler.json
}

resource "aws_scheduler_schedule" "this" {
  name                         = var.name
  schedule_expression          = var.schedule_expression
  schedule_expression_timezone = var.schedule_timezone
  state                        = var.schedule_enabled ? "ENABLED" : "DISABLED"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_sfn_state_machine.this.arn
    role_arn = aws_iam_role.scheduler.arn
    input    = jsonencode({})
  }

  depends_on = [aws_iam_role_policy.scheduler]
}
