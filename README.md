# Procurement Watchdog — GCP Platform

Production-grade Terraform infrastructure for deploying the [Procurement Watchdog Lakehouse](../procurement-watchdog-lakehouse) to Google Cloud Platform.

Ingests Polish public procurement data (BZP) via date-filtered API, transforms it through a medallion lakehouse (bronze/silver/gold), and serves analytical marts via BigQuery external tables for Looker Studio dashboards.

---

## Architecture

```
                           ┌─────────────────────┐
                           │   Cloud Scheduler    │
                           │  (backfill + daily)  │
                           └────┬───────────┬─────┘
                                │           │
                     OIDC token │           │ OIDC token
                                ▼           ▼
                  ┌──────────────┐   ┌──────────────┐
                  │  Dispatcher  │   │   Launcher   │
                  │ (Cloud Run)  │   │ (Cloud Run)  │
                  └──────┬───────┘   └──────┬───────┘
                         │                  │
              triggers   │                  │  submits
              job exec   │                  │  batch
                         ▼                  ▼
              ┌──────────────────┐  ┌───────────────────┐
              │   Downloader     │  │ Dataproc Serverless│
              │  (Cloud Run Job) │  │   (Spark Batch)    │
              └────────┬─────────┘  └────────┬──────────┘
                       │                     │
          Public API   │                     │ reads bronze_raw
          (BZP)  ──────┘                     │ writes bronze/silver/gold
                       │                     │
                       ▼                     ▼
              ┌──────────────────────────────────────────┐
              │              Google Cloud Storage         │
              │                                          │
              │  bronze_raw/source=api/dt=YYYY-MM-DD/    │
              │  bronze/dt=YYYY-MM-DD/                   │
              │  silver/...                              │
              │  gold/case_mart/date=YYYY-MM-DD/         │  ◄── Canonical
              │  gold/buyer_mart/date=YYYY-MM-DD/        │
              │  gold/market_mart/date=YYYY-MM-DD/       │
              │  gold/signals_buyer_daily/date=YYYY-MM-DD│
              │  state/backfill/dt=YYYY-MM-DD.done       │
              └───────────────┬──────────────────────────┘
                              │
                              │ External Tables (Parquet)
                              ▼
              ┌──────────────────────────────────┐
              │   BigQuery (Serving Layer Only)   │
              │                                  │
              │  case_mart          (external)    │
              │  buyer_mart         (external)    │
              │  market_mart        (external)    │
              │  signals_buyer_daily (external)   │
              │  v_institution_summary (view)     │
              │  v_risk_metrics        (view)     │
              └──────────────┬───────────────────┘
                             │
                             ▼
              ┌──────────────────────────────────┐
              │       Looker Studio Dashboards    │
              │       (NOT managed by Terraform)  │
              └──────────────────────────────────┘
```

### Key Design Decisions

- **Gold in GCS is canonical storage.** BigQuery serves as a query/visualization layer via external tables — no data duplication, no ETL into BigQuery.
- **API fetch is decoupled from Spark transforms.** Different failure domains, different retry semantics, different cost profiles.
- **Spark batch jobs are NOT managed by Terraform.** The launcher service submits them dynamically. Terraform only provisions the infrastructure (service accounts, permissions, scheduler triggers).
- **Looker Studio dashboards are NOT managed by Terraform.** They connect to BigQuery external tables which are managed.

---

## Backfill Strategy

The system handles both daily incremental ingestion and large historical backfills (60GB+ annual loads).

### How Backfill Works

```
Cloud Scheduler (e.g. every hour)
        │
        ▼
Dispatcher Service
  1. Lists state/backfill/dt=*.done in GCS
  2. Computes next unprocessed date from backfill_start_date
  3. Checks running job count < max_backfill_concurrency
  4. Triggers Downloader Job with TARGET_DATE=YYYY-MM-DD
        │
        ▼
Downloader Job (per date)
  1. Calls BZP API with date filter for all 14 notice types
  2. Paginates with exponential backoff
  3. Writes compressed JSONL to bronze_raw/source=api/dt=YYYY-MM-DD/
  4. On success, writes marker: state/backfill/dt=YYYY-MM-DD.done
```

### Idempotency

Every component is idempotent by design:

| Component | Mechanism |
|-----------|-----------|
| **Downloader** | Writes to deterministic GCS path — rerun overwrites same partition. Completion marker in state bucket gates the dispatcher. |
| **Spark Bronze** | Overwrites `bronze/noticeType=<TYPE>/publicationDateDay=YYYY-MM-DD/` partition. |
| **Spark Silver** | Overwrites `silver/common_envelope/publicationDateDay=YYYY-MM-DD/` partition. |
| **Spark Gold** | Overwrites `gold/<mart>/date=YYYY-MM-DD/` partition. |
| **Dispatcher** | Scans state markers — already-done dates are skipped. Safe to invoke repeatedly. |

### Rate Limiting

- **Dispatcher-level**: `max_backfill_concurrency` variable limits simultaneous downloader jobs (default: 2 dev, 5 prod).
- **Downloader-level**: Exponential backoff on API calls. Paginated at 500 records/page with configurable delays.
- **Scheduler-level**: Cron frequency controls how often new dates are picked up (hourly/bi-hourly).

### Restartability

If a backfill is interrupted:
1. Completed dates have `.done` markers in the state bucket — they are skipped.
2. In-progress dates have no marker — the dispatcher will re-trigger them.
3. Partial GCS writes are overwritten on retry (deterministic paths).

No manual cleanup required.

---

## BigQuery Serving Layer

BigQuery is configured as a **read-only serving layer** using external tables:

- **External tables** point directly at Gold Parquet files in GCS using Hive partitioning (`date=YYYY-MM-DD`).
- **No data is copied** into BigQuery managed storage — queries read directly from GCS.
- **Automatic schema detection** via Parquet metadata (autodetect = true).
- **Optional views** provide pre-built aggregations (institution summary, risk metrics).

### Cost Implications

- No BigQuery storage costs (data lives in GCS).
- Query costs are based on bytes scanned from GCS (partition pruning reduces cost significantly).
- For high-frequency dashboards, consider materializing critical views as native tables (outside Terraform).

---

## Connecting Looker Studio

1. Open [Looker Studio](https://lookerstudio.google.com/).
2. Create a new data source → **BigQuery**.
3. Select project → dataset `procurement_serving` (or your configured dataset ID).
4. Choose an external table (e.g., `case_mart`) or a view (e.g., `v_institution_summary`).
5. Build your dashboard.

Ensure the Looker Studio user's Google account is listed in `dashboard_viewer_members` in your tfvars, or has BigQuery Data Viewer access via another mechanism.

---

## Repository Structure

```
procurement-watchdog-gcp-platform/
├── modules/
│   ├── storage/                    # GCS buckets (medallion layers + state)
│   ├── iam/                        # Service accounts + bucket-level IAM
│   ├── cloud_run_downloader_job/   # API fetch Cloud Run Job
│   ├── cloud_run_dispatcher/       # Backfill orchestrator service
│   ├── cloud_run_launcher/         # Spark batch submission service
│   ├── scheduler/                  # Cloud Scheduler triggers
│   ├── dataproc_permissions/       # Dataproc Serverless IAM
│   └── bigquery_serving/           # External tables + views
├── envs/
│   ├── dev/                        # Dev environment config
│   │   ├── backend.tf
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── dev.tfvars.example
│   └── prod/                       # Prod environment config
│       ├── backend.tf
│       ├── main.tf
│       ├── variables.tf
│       └── prod.tfvars.example
├── .gitignore
└── README.md
```

---

## Deployment Guide

### Prerequisites

- Terraform >= 1.5
- `gcloud` CLI authenticated with sufficient permissions
- A GCP project with billing enabled
- A GCS bucket for Terraform state (created manually)

### 1. Create Terraform State Bucket

```bash
export PROJECT_ID="your-project-id"
export TF_STATE_BUCKET="procwatch-tfstate-dev"

gsutil mb -p $PROJECT_ID -l EU gs://$TF_STATE_BUCKET
gsutil versioning set on gs://$TF_STATE_BUCKET
```

### 2. Configure Variables

```bash
cd envs/dev
cp dev.tfvars.example dev.tfvars
# Edit dev.tfvars with your project_id, region, etc.
```

### 3. Initialize and Plan

```bash
terraform init -backend-config="bucket=$TF_STATE_BUCKET"
terraform plan -var-file=dev.tfvars
```

### 4. Apply

```bash
terraform apply -var-file=dev.tfvars
```

### 5. Build and Push Container Images

```bash
# From the procurement-watchdog-lakehouse repository
export REGION="europe-central2"
export AR_REPO="$REGION-docker.pkg.dev/$PROJECT_ID/procwatch-pipeline"

# Authenticate Docker to Artifact Registry
gcloud auth configure-docker $REGION-docker.pkg.dev

# Build and push downloader image
docker build -t $AR_REPO/downloader:v1.0.0 -f Dockerfile.downloader .
docker push $AR_REPO/downloader:v1.0.0

# Build and push dispatcher image
docker build -t $AR_REPO/dispatcher:v1.0.0 -f Dockerfile.dispatcher .
docker push $AR_REPO/dispatcher:v1.0.0

# Build and push launcher image
docker build -t $AR_REPO/launcher:v1.0.0 -f Dockerfile.launcher .
docker push $AR_REPO/launcher:v1.0.0
```

### 6. Deploy to Production

```bash
cd envs/prod
cp prod.tfvars.example prod.tfvars
# Edit prod.tfvars — use pinned image tags, not "latest"

terraform init -backend-config="bucket=procwatch-tfstate-prod"
terraform plan -var-file=prod.tfvars
terraform apply -var-file=prod.tfvars
```

---

## Configuration Variables

| Variable | Description | Dev Default | Prod Default |
|----------|-------------|-------------|--------------|
| `project_id` | GCP project ID | (required) | (required) |
| `region` | GCP region | (required) | (required) |
| `environment` | Environment name | `dev` | `prod` |
| `naming_prefix` | Resource name prefix | `procwatch` | `procwatch` |
| `bucket_location` | GCS location | `EU` | `EU` |
| `image_tag` | Container image tag | `latest` | `v1.0.0` |
| `backfill_schedule_cron` | Backfill trigger cron | `0 */4 * * *` | `0 * * * *` |
| `transformation_schedule_cron` | Spark trigger cron | `30 7 * * *` | `30 6 * * *` |
| `max_backfill_concurrency` | Parallel download jobs | `2` | `5` |
| `backfill_start_date` | Backfill window start | `2024-01-01` | `2024-01-01` |
| `enable_bigquery_serving` | Create BQ layer | `false` | `true` |
| `spark_properties` | Spark config overrides | `{}` | executor tuning |

---

## Cost Considerations

| Component | Cost Driver | Optimization |
|-----------|-------------|-------------|
| **Cloud Run Jobs** | vCPU-seconds + memory | Scale to zero between runs. 1 vCPU/1GB dev, 2 vCPU/2GB prod. |
| **Cloud Run Services** | vCPU-seconds + memory | Scale to zero (min instances = 0). Only active during scheduler invocations. |
| **GCS Storage** | Storage volume + operations | Lifecycle rules transition old bronze_raw to Nearline. Gold stays Standard for query performance. |
| **Dataproc Serverless** | vCPU-hours + memory-hours | Dynamic allocation. No idle cluster costs. Batch jobs run and terminate. |
| **BigQuery** | Bytes scanned per query | External tables = no storage cost. Partition pruning on date reduces scan volume. |
| **Cloud Scheduler** | $0.10/job/month | Negligible (2 jobs). |
| **Artifact Registry** | Storage volume | Minimal (a few container images). |

### Estimated Monthly Cost (Prod, Steady State)

- Backfill phase (one-time): ~$50-150 depending on date range and concurrency
- Daily operations: ~$10-30/month (dominated by Dataproc Serverless compute)
- Storage: scales with data volume (~$0.02/GB/month Standard, less with lifecycle rules)

---

## Security

- **No secrets in Terraform.** All authentication uses GCP service accounts with Workload Identity.
- **Least-privilege IAM.** Each component has a dedicated service account with only the permissions it needs.
- **Bucket-level IAM** (not project-level). Downloader can only write to bronze_raw + state. Pipeline runtime can read bronze_raw and write downstream layers.
- **Internal-only ingress** on dispatcher and launcher services. Only Cloud Scheduler (via OIDC) can invoke them.
- **No hardcoded project IDs.** All resource names are parameterized.

---

## What NOT to Commit

- `*.tfvars` files (contain project-specific configuration)
- `*.tfstate` files (managed by remote backend)
- `.terraform/` directory (provider plugins, downloaded on init)
- Service account key files (`.json` credentials)
- `.env` files

These are all covered by `.gitignore`.

---

## FAQ

**Q: Why not use BigQuery as the primary data store?**
A: Gold Parquet in GCS is the canonical data format. It is portable (not locked to BigQuery), cheaper for storage, and directly consumable by Spark, Pandas, DuckDB, or any Parquet-aware tool. BigQuery external tables give us SQL query capability and Looker Studio connectivity without data duplication.

**Q: Why not manage Spark batch jobs in Terraform?**
A: Spark batch jobs are ephemeral compute — they run, process data, and terminate. Terraform manages durable infrastructure (buckets, service accounts, schedulers). The launcher service handles dynamic batch submission with runtime parameters.

**Q: Why Cloud Run instead of Cloud Functions?**
A: Cloud Run Jobs support longer timeouts (up to 24h), larger memory, and custom container images. The pipeline's Docker image includes Java/Spark dependencies that exceed Cloud Functions limits.

**Q: How do I re-run a specific backfill date?**
A: Delete the corresponding marker from the state bucket (`gsutil rm gs://<state-bucket>/backfill/dt=YYYY-MM-DD.done`) and the dispatcher will re-trigger it on next invocation.
