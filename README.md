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
│   ├── artifact_registry/        # Docker registry (spark repo)
│   ├── cloud_run_downloader/     # bzp-downloader Cloud Run Job
│   ├── bigquery/                 # procurement_silver + procurement_obs datasets
│   └── workflows/                # Cloud Workflows (bzp-daily) + Cloud Scheduler
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

---

## Deployment Guide

### Prerequisites

- Terraform >= 1.5
- `gcloud` CLI authenticated with `roles/owner` or equivalent
- A GCP project with billing enabled
- A GCS bucket for Terraform state (created manually)

### 1. Create Terraform State Bucket

```bash
export PROJECT_ID="your-project-id"
export TF_STATE_BUCKET="procwatch-tfstate"

gsutil mb -p $PROJECT_ID -l EU gs://$TF_STATE_BUCKET
gsutil versioning set on gs://$TF_STATE_BUCKET
```

### 2. Configure Variables

```bash
cd envs/dev
cp dev.tfvars.example dev.tfvars
# Edit dev.tfvars — set project_id and region at minimum
```

### 3. Initialize and Apply

```bash
terraform init -backend-config="bucket=$TF_STATE_BUCKET"
terraform plan  -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars
```

Key outputs after apply:
- `lakehouse_bucket` — `gs://{project_id}-lakehouse`
- `artifact_registry_url` — base URL for Docker images
- `spark_image_base` — base URI for the Spark container (append `:<tag>`)
- `downloader_image_base` — base URI for the downloader container (append `:<tag>`)
- `dataproc_subnet` — self-link to pass as `DATAPROC_SUBNET`
- `workflow_name` — `bzp-daily`

### 4. Build and Push Container Images

From the `procurement-watchdog-lakehouse` repository:

```bash
GIT_SHA=$(git rev-parse --short HEAD)
REGION="europe-west1"
PROJECT_ID="your-project-id"

# Authenticate Docker to Artifact Registry
gcloud auth configure-docker ${REGION}-docker.pkg.dev

# Spark container (Dataproc Serverless batches)
SPARK_IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/spark/procurement-spark:${GIT_SHA}"
docker build -f Dockerfile.spark --build-arg GIT_SHA=${GIT_SHA} -t ${SPARK_IMAGE} .
docker push ${SPARK_IMAGE}

# Downloader container (Cloud Run Job)
DL_IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/spark/procurement-downloader:${GIT_SHA}"
docker build -f Dockerfile.downloader --build-arg GIT_SHA=${GIT_SHA} -t ${DL_IMAGE} .
docker push ${DL_IMAGE}
```

Set `dataproc_container_image = "${SPARK_IMAGE}"` in your tfvars and re-run `terraform apply`.

### 5. Upload Pipeline Scripts to GCS

```bash
export LAKEHOUSE_BUCKET="${PROJECT_ID}-lakehouse"
gsutil -m cp scripts/pipeline/*.py gs://${LAKEHOUSE_BUCKET}/jobs/
```

### 6. Create BigQuery External Iceberg Tables

After the first pipeline run populates the silver layer:

```bash
export RUNTIME_ENV=gcp
export LAKEHOUSE_BUCKET="${PROJECT_ID}-lakehouse"
export GCP_PROJECT="${PROJECT_ID}"
export BQ_DATASET=procurement_silver

cd procurement-watchdog-lakehouse
python scripts/ops/setup_bq_external_tables.py --format iceberg
```

Re-run this script when new notice types are added or the silver schema changes.

### Trigger a Manual Run

```bash
gcloud workflows run bzp-daily \
  --location=europe-west1 \
  --data='{"target_date":"2025-03-15"}'
```

---

## Configuration Variables

| Variable | Description | Dev Default | Prod Default |
|----------|-------------|-------------|--------------|
| `project_id` | GCP project ID | (required) | (required) |
| `region` | GCP region | (required) | (required) |
| `environment` | Environment label | `dev` | `prod` |
| `naming_prefix` | Resource name prefix | `procwatch` | `procwatch` |
| `bucket_location` | GCS + BQ location | `EU` | `EU` |
| `dataproc_subnet_cidr` | Dataproc subnet CIDR | `10.100.0.0/24` | `10.100.0.0/24` |
| `downloader_image_tag` | Downloader image tag | `latest` | (required) |
| `dataproc_container_image` | Spark image full URI | `""` (set after first build) | (required) |
| `bq_silver_dataset_id` | Silver BQ dataset | `procurement_silver` | same |
| `bq_obs_dataset_id` | Observability BQ dataset | `procurement_obs` | same |
| `schedule_cron` | Pipeline cron schedule (UTC) | `0 3 * * *` | same |
| `time_zone` | Scheduler UI timezone | `Europe/Warsaw` | same |

---

## IAM Design

Three service accounts with least-privilege access:

| SA | Used by | Key permissions |
|----|---------|-----------------|
| `procwatch-downloader` | Cloud Run Job | `storage.objectAdmin` on lakehouse bucket |
| `procwatch-pipeline` | Dataproc Serverless batches | `storage.objectAdmin` on lakehouse bucket, `dataproc.worker`, `bigquery.dataEditor` on both BQ datasets |
| `procwatch-orchestrator` | Cloud Workflows | `run.developer` (submit Cloud Run Job executions), `dataproc.editor` (submit batches), `logging.logWriter` (sys.log calls), `iam.serviceAccountUser` on pipeline SA |
| `procwatch-sched-invoke` | Cloud Scheduler | `workflows.invoker` on the `bzp-daily` workflow |

---

## Cost Considerations

| Component | Cost Driver |
|-----------|-------------|
| **Dataproc Serverless** | Per vCPU-hour + memory-hour. No idle cluster costs. Scales per batch. |
| **Cloud Run Job** | Per vCPU-second + memory-second. Only runs when triggered (~minutes/day). |
| **Cloud Workflows** | Per step executed (~$0.01/execution). Negligible. |
| **GCS** | Storage volume. Single bucket with folder prefixes keeps costs low. |
| **BigQuery** | Bytes scanned per query (external tables — no storage cost for silver data). |
| **Artifact Registry** | Storage for container images. |

---

## Security

- **No secrets in Terraform.** Authentication via GCP service accounts and Workload Identity.
- **Least-privilege IAM.** Each service account has exactly the permissions it needs — no project-wide Editor/Owner.
- **Bucket-level IAM.** Downloader, pipeline, and orchestrator SAs each get `objectAdmin` on the single lakehouse bucket.
- **Private Google Access.** Dataproc Serverless workers use a dedicated subnet with PGA — no public IPs needed.
- **No hardcoded project IDs.** All resource names are parameterized via variables.

---

## What NOT to Commit

- `*.tfvars` (contain project-specific config — covered by `.gitignore`)
- `*.tfstate` (managed by remote backend)
- `.terraform/` (downloaded on `terraform init`)
- Service account key JSON files
