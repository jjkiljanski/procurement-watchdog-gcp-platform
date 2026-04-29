# Procurement Watchdog — GCP Platform

Terraform infrastructure for deploying the [Procurement Watchdog Lakehouse](../procurement-watchdog-lakehouse) to Google Cloud Platform.

Ingests Polish public procurement data (BZP) via the BZP API, transforms it through bronze → silver (Apache Iceberg) layers using Dataproc Serverless (PySpark), and exposes the silver layer as BigQuery external Iceberg tables.

---

## Architecture

```
   Cloud Scheduler (bzp-daily-trigger, 03:00 UTC)
          │
          ▼
   Cloud Workflows (bzp-daily)
          │
          │ step 1: Cloud Run Job
          ▼
   ┌────────────────────────┐
   │   Cloud Run Job        │  bzp-downloader
   │   fetch_bzp_yesterday  │  writes bronze_raw JSON
   └───────────┬────────────┘
               │
               ▼
   ┌────────────────────────┐
   │   GCS bucket           │  {project_id}-lakehouse
   │   /bronze_raw/         │  bzp_YYYY-MM-DD.json
   └───────────┬────────────┘
               │ step 2: Dataproc Serverless
               ▼
   ┌────────────────────────┐
   │  Dataproc Serverless   │  procurement-spark image
   │  build_bronze.py       │  → /bronze/notices/noticeType=*/publicationDateDay=*/
   └───────────┬────────────┘
               │ step 3
               ▼
   ┌────────────────────────┐
   │  Dataproc Serverless   │
   │  build_silver_day.py   │  → /iceberg/notice_type_tables/
   │                        │    /iceberg/common/
   └───────────┬────────────┘
               │ step 4
               ▼
   ┌────────────────────────┐
   │  Dataproc Serverless   │
   │  build_silver_         │  → /iceberg/notice_update_deltas/
   │  update_deltas.py      │
   └───────────┬────────────┘
               │
               ▼
   ┌────────────────────────┐
   │  BigQuery              │  created by setup_bq_external_tables.py
   │  external Iceberg      │  dataset: procurement_silver
   │  tables over silver    │
   └────────────────────────┘
```

---

## Repository Structure

```
procurement-watchdog-gcp-platform/
├── modules/
│   ├── storage/                  # Single lakehouse GCS bucket
│   ├── network/                  # Dataproc Serverless subnet (PGA)
│   ├── iam/                      # Service accounts + IAM bindings
│   ├── artifact_registry/        # Docker registry (spark + downloader repos)
│   ├── cloud_run_downloader/     # bzp-downloader Cloud Run Job
│   ├── bigquery/                 # procurement_silver + procurement_obs datasets
│   ├── workflows/                # Cloud Workflows (bzp-daily) + Cloud Scheduler
│   ├── wif/                      # Workload Identity Federation + CI service account
│   └── alerting/                 # Email notification channel + workflow failure alert + billing budget
├── envs/
│   ├── dev/                      # Dev environment config
│   │   ├── backend.tf
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── dev.tfvars.example
│   └── prod/                     # Prod environment config
│       ├── backend.tf
│       ├── main.tf
│       ├── variables.tf
│       └── prod.tfvars.example
├── .gitignore
└── README.md
```

---

## GCP Services Provisioned

| Service | Purpose | Module |
|---------|---------|--------|
| **GCS bucket** | bronze_raw, bronze, silver (Iceberg), jobs, _processed | `storage` |
| **Subnet** | Dataproc Serverless workers (Private Google Access) | `network` |
| **Service Accounts** | downloader, pipeline, orchestrator (least-privilege) | `iam` |
| **Artifact Registry** | Docker images: procurement-spark, procurement-downloader | `artifact_registry` |
| **Cloud Run Job** | `bzp-downloader` — fetches BZP API data | `cloud_run_downloader` |
| **BigQuery datasets** | `procurement_silver`, `procurement_obs` | `bigquery` |
| **Cloud Workflows** | `bzp-daily` — orchestrates the 4-step daily pipeline | `workflows` |
| **Cloud Scheduler** | `bzp-daily-trigger` — fires `bzp-daily` at 03:00 UTC | `workflows` |
| **Workload Identity Pool** | Keyless GitHub Actions auth (no SA key JSON) | `wif` |
| **CI Service Account** | Used by GitHub Actions to deploy images, scripts, workflows | `wif` |
| **Cloud Monitoring alert** | Email on `bzp-daily` workflow execution failure | `alerting` |
| **Billing budget** | Email at 80% and 100% of monthly spend cap | `alerting` |

---

## CI/CD

Container images, pipeline scripts, Cloud Workflows YAMLs, BigQuery table definitions, and Cloud Scheduler payloads are all managed by the GitHub Actions pipeline in the lakehouse repo — **not** by Terraform. Terraform owns the long-lived infrastructure; CI/CD owns every deployment-time artifact.

### How keyless auth works (Workload Identity Federation)

GitHub Actions generates a short-lived OIDC token for each run. GCP exchanges it for a temporary access token via the WIF pool, which is scoped to the specific GitHub repository. No service account key JSON is stored anywhere.

### GitHub Secrets required

After `terraform apply`, copy the two outputs to GitHub repository secrets (Settings → Secrets and variables → Actions):

| Secret name | Terraform output |
|-------------|-----------------|
| `DEV_WIF_PROVIDER` | `wif_provider` (in `envs/dev`) |
| `DEV_CI_SERVICE_ACCOUNT` | `ci_service_account` (in `envs/dev`) |
| `PROD_WIF_PROVIDER` | `wif_provider` (in `envs/prod`) |
| `PROD_CI_SERVICE_ACCOUNT` | `ci_service_account` (in `envs/prod`) |

### CI/CD triggers

| Event | Action |
|-------|--------|
| Push to `main` | Lint + test + deploy to dev (no backfill) |
| Push of `v*` tag | Lint + test + deploy to dev (with backfill) + deploy to prod (with backfill) |

---

## Deployment Guide

### Prerequisites

- Terraform >= 1.5
- `gcloud` CLI authenticated with `roles/owner` or equivalent
- A GCP project with billing enabled
- A GCS bucket for Terraform state (created manually)

### 1. Bootstrap the Cloud Resource Manager API

Terraform uses this API to enable all other APIs, but it must be enabled manually first (one-time):

```bash
gcloud services enable cloudresourcemanager.googleapis.com --project=YOUR_PROJECT_ID
```

### 2. Create Terraform State Bucket

```bash
export PROJECT_ID="your-project-id"
export TF_STATE_BUCKET="procwatch-tfstate"

gsutil mb -p $PROJECT_ID -l EU gs://$TF_STATE_BUCKET
gsutil versioning set on gs://$TF_STATE_BUCKET
```

### 3. Configure Variables

```bash
cd envs/dev
cp dev.tfvars.example dev.tfvars
# Edit dev.tfvars — set at minimum: project_id, region, github_repo
```

### 4. Initialize and Apply

```bash
terraform init -backend-config="bucket=$TF_STATE_BUCKET"
terraform plan  -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars
```

Key outputs after apply:

| Output | Description |
|--------|-------------|
| `lakehouse_bucket` | `gs://{project_id}-lakehouse` |
| `artifact_registry_url` | Base URL for Docker images |
| `dataproc_subnet` | Self-link to pass as `DATAPROC_SUBNET` |
| `workflow_name` | `bzp-daily` |
| `wif_provider` | Copy to `DEV_WIF_PROVIDER` GitHub secret |
| `ci_service_account` | Copy to `DEV_CI_SERVICE_ACCOUNT` GitHub secret |

### 5. Add GitHub Secrets

Copy `wif_provider` and `ci_service_account` from the Terraform outputs into the GitHub repository secrets for the lakehouse repo (see table in [CI/CD](#cicd) section above).

### 6. Push to Main

From the lakehouse repo, push a commit to `main`. The CI/CD pipeline will automatically:
- Build and push the Spark and downloader Docker images
- Upload pipeline scripts to GCS
- Deploy Cloud Workflows YAMLs
- Update the Cloud Run job image and Cloud Scheduler payload
- Run BQ external table setup

---

## Configuration Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `project_id` | GCP project ID | (required) |
| `region` | GCP region | (required) |
| `github_repo` | GitHub repo in `owner/name` format for WIF | (required) |
| `backfill_start_date` | Earliest date for backfill runs (`YYYY-MM-DD`) | (required) |
| `environment` | Environment label | `dev` |
| `naming_prefix` | Resource name prefix | `procwatch` |
| `bucket_location` | GCS + BQ location | `EU` |
| `dataproc_subnet_cidr` | Dataproc Serverless subnet CIDR | `10.100.0.0/24` |
| `bq_silver_dataset_id` | Silver BQ dataset name | `procurement_silver` |
| `bq_obs_dataset_id` | Observability BQ dataset name | `procurement_obs` |
| `schedule_cron` | Daily pipeline cron schedule (UTC) | `0 3 * * *` |
| `time_zone` | Scheduler timezone | `Europe/Warsaw` |
| `alert_email` | Recipient for pipeline failure and budget alerts | (required) |
| `billing_account` | Billing account ID for budget (dev only; prod infers from project) | (required in dev) |
| `monthly_budget_amount` | Monthly spend cap in the billing account's currency; alerts at 80% and 100% | `20` (dev) / `50` (prod) |

---

## IAM Design

Four service accounts with least-privilege access:

| SA | Used by | Key permissions |
|----|---------|-----------------|
| `procwatch-downloader` | Cloud Run Job | `storage.objectAdmin` on lakehouse bucket |
| `procwatch-pipeline` | Dataproc Serverless batches | `storage.objectAdmin` on lakehouse bucket, `dataproc.worker`, `bigquery.dataEditor` |
| `procwatch-orchestrator` | Cloud Workflows | `run.developer`, `dataproc.editor`, `iam.serviceAccountUser` on pipeline SA |
| `procwatch-ci` | GitHub Actions (via WIF) | `artifactregistry.writer`, `run.developer`, `workflows.editor`, `workflows.invoker`, `cloudscheduler.admin`, `bigquery.dataEditor`, `storage.objectAdmin` on bucket, `iam.serviceAccountUser` on orchestrator and downloader SAs |

---

## Cost Considerations

| Component | Cost Driver |
|-----------|-------------|
| **Dataproc Serverless** | Per vCPU-hour + memory-hour. No idle cluster costs. Scales per batch. |
| **Cloud Run Job** | Per vCPU-second + memory-second. Only runs when triggered (~minutes/day). |
| **Cloud Workflows** | Per step executed (~$0.01/execution). Negligible. |
| **GCS** | Storage volume. Single bucket with folder prefixes keeps costs low. |
| **BigQuery** | Bytes scanned per query (external tables — no storage cost for silver data). |
| **Artifact Registry** | Storage for container images. Only the latest image is retained per repo. |

---

## Alerting

Two alerts are provisioned per environment by the `alerting` module:

| Alert | Trigger | Channel |
|-------|---------|---------|
| **Pipeline failure** | `bzp-daily` Cloud Workflow execution logs `severity=ERROR` | Email (rate-limited to 1/hour) |
| **Budget** | Project spend reaches 80% or 100% of `monthly_budget_usd` | Email |

Both alerts send to the `alert_email` variable. The workflow failure alert includes a direct link to the Cloud Workflows executions console in the notification body.

---

## Security

- **No secrets in Terraform or CI.** GitHub Actions authenticates via Workload Identity Federation — no SA key JSON stored anywhere.
- **Least-privilege IAM.** Each service account has exactly the permissions it needs — no project-wide Editor/Owner.
- **WIF scoped to repository.** The identity pool only accepts tokens from the configured GitHub repository.
- **Bucket-level IAM.** Downloader, pipeline, and CI SAs each get `objectAdmin` on the single lakehouse bucket; no broader storage access.
- **Private Google Access.** Dataproc Serverless workers use a dedicated subnet with PGA — no public IPs needed.
- **No hardcoded project IDs.** All resource names are parameterised via variables.

---

## What NOT to Commit

- `*.tfvars` (contain project-specific config — covered by `.gitignore`)
- `*.tfstate` (managed by remote backend)
- `.terraform/` (downloaded on `terraform init`)
- Service account key JSON files
