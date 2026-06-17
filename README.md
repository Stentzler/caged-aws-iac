# AWS IaC

Terraform infrastructure layout for AWS environments and reusable modules.

## Structure

- `environments/shared`: Account-wide GitHub OIDC provider and Lambda deployment roles.
- `environments/dev`: Terraform configuration for the development environment.
- `environments/prod`: Terraform configuration for the production environment.
- `modules`: Reusable Terraform modules for AWS resources.

## Shared deployment identity

The shared stack creates the GitHub Actions OIDC provider once for the AWS
account and narrowly scoped deployment roles for the Lambda repositories and
the ECS processing-task repository in development and production. Apply it
before configuring GitHub Actions:

```bash
terraform -chdir=environments/shared init
terraform -chdir=environments/shared plan -out=tfplan
terraform -chdir=environments/shared apply tfplan
terraform -chdir=environments/shared output deploy_role_arns
```

Configure the appropriate role ARN as `AWS_DEPLOY_ROLE_ARN` in each Lambda
repository. Use GitHub Environment secrets named `dev` and `prod` when both
environments are enabled, because each environment assumes a different role.
Restrict the `dev` GitHub Environment to `develop` and the `prod` environment
to `main`, with required reviewers for production if appropriate.

Each AWS trust policy accepts only its exact repository and GitHub Environment.
Each Lambda deployment role can update code, publish versions, and promote
aliases only for its corresponding Lambda function. Each ECS deployment role
can push images to its ECR repository, register task-definition revisions, and
pass only the processing task's execution and application roles. It cannot run
the processing task; Step Functions owns runtime invocation.

## Development architecture

The development stack creates:

- A private, encrypted, versioned S3 bucket for downloaded CAGED archives.
- DynamoDB table `downloaded_files_registry` with `registry_id` as its key.
- DynamoDB table `caged_processes` keyed by `reference_month` and `process_id`.
- ECR repository `caged-dev-processing-task` for the processing container image.
- ECS cluster and Fargate task definition for `caged-dev-processing-task`.
- Step Functions permission to run the latest processing task revision after
  downloads complete.
- `caged-dev-check-availability` and `caged-dev-download` Lambda functions.
- A Standard Step Functions workflow that checks availability and sequentially
  downloads each new file.
- An EventBridge Scheduler schedule for 06:00 `America/Sao_Paulo` each day.

The schedule is disabled by default. Terraform owns Lambda configuration,
permissions, and environment aliases. The Lambda repositories' CI workflows
own function code updates, publish immutable versions, and promote the aliases.

## Bootstrap development

Prerequisites:

- Terraform 1.6 or newer.
- AWS credentials for `us-east-1`.
- `AWS_DEPLOY_ROLE_ARN` configured in both Lambda GitHub repositories with
  permission to update their corresponding function code.

Create the infrastructure with the schedule disabled:

```bash
terraform -chdir=environments/dev init
terraform -chdir=environments/dev apply
```

Terraform initially installs a bootstrap handler. Run each Lambda repository's
`Deploy` workflow before starting the state machine.

Seed the registry baseline from `caged-check-availability-lambda`:

```bash
uv run python scripts/seed_registry.py \
  --table-name downloaded_files_registry \
  --region us-east-1
```

An empty registry must not be used: the first scan would discover the complete
FTP history and exceed the availability Lambda's 12-file safety limit. The
baseline marks the historical files through April 2026 as already downloaded.

After both function packages are deployed and the registry is seeded, set
`schedule_enabled = true` in `environments/dev/terraform.tfvars` and apply
again.

## Workflow result

When no files are available, the workflow returns:

```json
{"status":"NO_NEW_FILES","files":[]}
```

After successful downloads, it returns `status=COMPLETED` and a `files` array.
Every file contains its year/month metadata, S3 bucket and key, and canonical
`s3_uri`. A failed download fails the complete execution after bounded retries.
