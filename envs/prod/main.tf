################################################################################
# Main Composition — Prod Environment
#
# Wires together all infrastructure modules for the production environment.
# Identical structure to dev — differences are in variable defaults and tfvars.
################################################################################

terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# --------------------------------------------------------------------------- #
# API Enablement
# --------------------------------------------------------------------------- #

locals {
  required_apis = [
    "storage.googleapis.com",
    "iam.googleapis.com",
    "dataproc.googleapis.com",
    "run.googleapis.com",
    "cloudscheduler.googleapis.com",
    "artifactregistry.googleapis.com",
    "bigquery.googleapis.com",
    "logging.googleapis.com",
  ]
}

resource "google_project_service" "apis" {
  for_each = toset(local.required_apis)

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# --------------------------------------------------------------------------- #
# Storage
# --------------------------------------------------------------------------- #

module "storage" {
  source = "../../modules/storage"

  project_id                   = var.project_id
  environment                  = var.environment
  naming_prefix                = var.naming_prefix
  bucket_location              = var.bucket_location
  bronze_raw_lifecycle_age_days = var.bronze_raw_lifecycle_age_days
  bronze_lifecycle_age_days    = var.bronze_lifecycle_age_days
  silver_lifecycle_age_days    = var.silver_lifecycle_age_days
  gold_lifecycle_age_days      = var.gold_lifecycle_age_days

  depends_on = [google_project_service.apis]
}

# --------------------------------------------------------------------------- #
# IAM
# --------------------------------------------------------------------------- #

module "iam" {
  source = "../../modules/iam"

  project_id              = var.project_id
  region                  = var.region
  naming_prefix           = var.naming_prefix
  bucket_names            = module.storage.bucket_names
  dispatcher_service_name = module.dispatcher.service_name
  launcher_service_name   = module.launcher.service_name

  depends_on = [google_project_service.apis]
}

# --------------------------------------------------------------------------- #
# Cloud Run — Downloader Job
# --------------------------------------------------------------------------- #

module "downloader" {
  source = "../../modules/cloud_run_downloader_job"

  project_id            = var.project_id
  region                = var.region
  environment           = var.environment
  naming_prefix         = var.naming_prefix
  downloader_sa_email   = module.iam.downloader_sa_email
  bronze_raw_bucket_url = module.storage.bucket_urls["bronze_raw"]
  state_bucket_url      = module.storage.bucket_urls["state"]
  image_tag             = var.image_tag
  cpu_limit             = "2"
  memory_limit          = "2Gi"
  job_timeout           = "3600s"

  depends_on = [google_project_service.apis]
}

# --------------------------------------------------------------------------- #
# Cloud Run — Dispatcher Service
# --------------------------------------------------------------------------- #

module "dispatcher" {
  source = "../../modules/cloud_run_dispatcher"

  project_id               = var.project_id
  region                   = var.region
  environment              = var.environment
  naming_prefix            = var.naming_prefix
  dispatcher_sa_email      = module.iam.dispatcher_sa_email
  state_bucket_url         = module.storage.bucket_urls["state"]
  downloader_job_name      = module.downloader.job_name
  artifact_registry_url    = module.downloader.artifact_registry_url
  image_tag                = var.image_tag
  max_backfill_concurrency = var.max_backfill_concurrency
  backfill_start_date      = var.backfill_start_date

  depends_on = [google_project_service.apis]
}

# --------------------------------------------------------------------------- #
# Cloud Run — Launcher Service
# --------------------------------------------------------------------------- #

module "launcher" {
  source = "../../modules/cloud_run_launcher"

  project_id                = var.project_id
  region                    = var.region
  environment               = var.environment
  naming_prefix             = var.naming_prefix
  launcher_sa_email         = module.iam.launcher_sa_email
  pipeline_runtime_sa_email = module.iam.pipeline_runtime_sa_email
  artifact_registry_url     = module.downloader.artifact_registry_url
  artifacts_bucket_url      = module.storage.bucket_urls["artifacts"]
  bronze_raw_bucket_url     = module.storage.bucket_urls["bronze_raw"]
  bronze_bucket_url         = module.storage.bucket_urls["bronze"]
  silver_bucket_url         = module.storage.bucket_urls["silver"]
  gold_bucket_url           = module.storage.bucket_urls["gold"]
  state_bucket_url          = module.storage.bucket_urls["state"]
  image_tag                 = var.image_tag
  spark_properties          = var.spark_properties

  depends_on = [google_project_service.apis]
}

# --------------------------------------------------------------------------- #
# Dataproc Serverless Permissions
# --------------------------------------------------------------------------- #

module "dataproc_permissions" {
  source = "../../modules/dataproc_permissions"

  project_id                = var.project_id
  pipeline_runtime_sa_email = module.iam.pipeline_runtime_sa_email
  enable_bigquery_access    = var.enable_bigquery_serving

  depends_on = [google_project_service.apis]
}

# --------------------------------------------------------------------------- #
# Cloud Scheduler
# --------------------------------------------------------------------------- #

module "scheduler" {
  source = "../../modules/scheduler"

  project_id                   = var.project_id
  region                       = var.region
  environment                  = var.environment
  naming_prefix                = var.naming_prefix
  backfill_schedule_cron       = var.backfill_schedule_cron
  transformation_schedule_cron = var.transformation_schedule_cron
  time_zone                    = var.scheduler_time_zone
  dispatcher_service_url       = module.dispatcher.service_url
  launcher_service_url         = module.launcher.service_url
  scheduler_invoker_sa_email   = module.iam.scheduler_invoker_sa_email

  depends_on = [google_project_service.apis]
}

# --------------------------------------------------------------------------- #
# BigQuery Serving (Enabled by default in prod)
# --------------------------------------------------------------------------- #

module "bigquery_serving" {
  source = "../../modules/bigquery_serving"
  count  = var.enable_bigquery_serving ? 1 : 0

  project_id               = var.project_id
  environment              = var.environment
  dataset_id               = var.bigquery_dataset_id
  dataset_location         = var.bucket_location
  gold_bucket_url          = module.storage.bucket_urls["gold"]
  dashboard_viewer_members = var.dashboard_viewer_members

  depends_on = [google_project_service.apis]
}

# --------------------------------------------------------------------------- #
# Outputs
# --------------------------------------------------------------------------- #

output "bucket_urls" {
  description = "GCS bucket URIs by layer."
  value       = module.storage.bucket_urls
}

output "service_account_emails" {
  description = "Service account emails."
  value = {
    downloader       = module.iam.downloader_sa_email
    dispatcher       = module.iam.dispatcher_sa_email
    pipeline_runtime = module.iam.pipeline_runtime_sa_email
    launcher         = module.iam.launcher_sa_email
    scheduler        = module.iam.scheduler_invoker_sa_email
  }
}

output "cloud_run_urls" {
  description = "Cloud Run service/job URLs."
  value = {
    dispatcher = module.dispatcher.service_url
    launcher   = module.launcher.service_url
    downloader = module.downloader.job_name
  }
}

output "bigquery_dataset_id" {
  description = "BigQuery dataset ID (empty if disabled)."
  value       = var.enable_bigquery_serving ? module.bigquery_serving[0].dataset_id : ""
}
