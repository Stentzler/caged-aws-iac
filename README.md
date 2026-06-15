# AWS IaC

Terraform infrastructure layout for AWS environments and reusable modules.

## Structure

- `environments/dev`: Terraform configuration for the development environment.
- `environments/prod`: Terraform configuration for the production environment.
- `modules`: Reusable Terraform modules for AWS resources.

## Development architecture

The development stack creates:

- A private, encrypted, versioned S3 bucket for downloaded CAGED archives.
- DynamoDB table `downloaded_files_registry` with `registry_id` as its key.
- `caged-dev-check-availability` and `caged-dev-download` Lambda functions.
- A Standard Step Functions workflow that checks availability and sequentially
  downloads each new file.
- An EventBridge Scheduler schedule for 06:00 `America/Sao_Paulo` each day.

The schedule is disabled by default. Terraform owns Lambda configuration and
permissions; the Lambda repositories' CI workflows own function code updates.

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
