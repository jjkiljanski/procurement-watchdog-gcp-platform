################################################################################
# Main Composition — Prod Environment
#
# Identical module structure to dev. Key differences:
#   - Creates the GCP project (dev project is assumed to pre-exist)
#   - force_destroy = false on storage
#   - Larger Cloud Run job limits
#   - Separate WIF pool + CI SA (distinct from dev)
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
  region = var.region
  # No default project — google_project resource manages project creation.
  # All module resources set project = var.project_id explicitly.
}

# --------------------------------------------------------------------------- #
# Project — create the prod GCP project within the org
#
# First apply: the user must have roles/resourcemanager.projectCreator in the org.
# If the project already exists, import it first:
#   terraform import google_project.prod PROJECT_ID
# --------------------------------------------------------------------------- #

resource "google_project" "prod" {
  name            = "Procurement Watchdog Prod"
  project_id      = var.project_id
  org_id          = var.org_id
  billing_account = var.billing_account

  labels = {
    environment = "prod"
    managed_by  = "terraform"
  }
}

# --------------------------------------------------------------------------- #
# API Enablement
# --------------------------------------------------------------------------- #

locals {
  required_apis = [
    "storage.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
    "dataproc.googleapis.com",
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "bigquery.googleapis.com",
    "logging.googleapis.com",
    "compute.googleapis.com",
    "workflows.googleapis.com",
    "workflowexecutions.googleapis.com",
    "cloudscheduler.googleapis.com",
    "monitoring.googleapis.com",
    "billingbudgets.googleapis.com",
  ]
}

resource "google_project_service" "apis" {
  for_each = toset(local.required_apis)

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false

  depends_on = [google_project.prod]
}

# --------------------------------------------------------------------------- #
# Storage
# --------------------------------------------------------------------------- #

module "storage" {
  source = "../../modules/storage"

  project_id      = var.project_id
  environment     = var.environment
  bucket_location = var.bucket_location
  force_destroy   = false

  depends_on = [google_project_service.apis["storage.googleapis.com"]]
}

# --------------------------------------------------------------------------- #
# Network
# --------------------------------------------------------------------------- #

module "network" {
  source = "../../modules/network"

  project_id    = var.project_id
  region        = var.region
  naming_prefix = var.naming_prefix
  network_name  = var.network_name
  subnet_cidr   = var.dataproc_subnet_cidr

  depends_on = [google_project_service.apis["compute.googleapis.com"]]
}

# --------------------------------------------------------------------------- #
# Artifact Registry
# --------------------------------------------------------------------------- #

module "artifact_registry" {
  source = "../../modules/artifact_registry"

  project_id  = var.project_id
  region      = var.region
  environment = var.environment

  depends_on = [google_project_service.apis["artifactregistry.googleapis.com"]]
}

# --------------------------------------------------------------------------- #
# IAM
# --------------------------------------------------------------------------- #

module "iam" {
  source = "../../modules/iam"

  project_id       = var.project_id
  naming_prefix    = var.naming_prefix
  lakehouse_bucket = module.storage.bucket_name

  depends_on = [module.storage]
}

# --------------------------------------------------------------------------- #
# Cloud Run — bzp-downloader job (larger limits for prod)
# --------------------------------------------------------------------------- #

module "downloader" {
  source = "../../modules/cloud_run_downloader"

  project_id          = var.project_id
  region              = var.region
  environment         = var.environment
  downloader_sa_email = module.iam.downloader_sa_email
  lakehouse_bucket    = module.storage.bucket_name
  bq_obs_dataset_id   = var.bq_obs_dataset_id
  cpu_limit           = "2"
  memory_limit        = "2Gi"

  depends_on = [module.iam, module.artifact_registry]
}

# --------------------------------------------------------------------------- #
# BigQuery
# --------------------------------------------------------------------------- #

module "bigquery" {
  source = "../../modules/bigquery"

  project_id        = var.project_id
  environment       = var.environment
  bq_location       = var.bq_location
  silver_dataset_id = var.bq_silver_dataset_id
  obs_dataset_id    = var.bq_obs_dataset_id
  pipeline_sa_email = module.iam.pipeline_sa_email

  depends_on = [module.iam]
}

# --------------------------------------------------------------------------- #
# Workflows
# --------------------------------------------------------------------------- #

module "workflows" {
  source = "../../modules/workflows"

  project_id                = var.project_id
  region                    = var.region
  naming_prefix             = var.naming_prefix
  environment               = var.environment
  orchestrator_sa_email     = module.iam.orchestrator_sa_email
  lakehouse_bucket          = module.storage.bucket_name
  pipeline_sa_email         = module.iam.pipeline_sa_email
  dataproc_subnet_self_link = module.network.dataproc_subnet_self_link
  downloader_job_name       = module.downloader.job_name
  bq_silver_dataset_id      = var.bq_silver_dataset_id
  bq_obs_dataset_id         = var.bq_obs_dataset_id
  schedule_cron             = var.schedule_cron
  time_zone                 = var.time_zone

  depends_on = [module.iam, module.network, module.storage, module.downloader]
}

# --------------------------------------------------------------------------- #
# WIF — keyless auth for GitHub Actions
# --------------------------------------------------------------------------- #

module "wif" {
  source = "../../modules/wif"

  project_id         = var.project_id
  naming_prefix      = var.naming_prefix
  github_repo        = var.github_repo
  lakehouse_bucket   = module.storage.bucket_name
  orchestrator_sa_id = module.iam.orchestrator_sa_id
  downloader_sa_id        = module.iam.downloader_sa_id
  scheduler_invoker_sa_id = module.workflows.scheduler_invoker_sa_id

  depends_on = [
    google_project_service.apis["iam.googleapis.com"],
    google_project_service.apis["iamcredentials.googleapis.com"],
    google_project_service.apis["sts.googleapis.com"],
    module.iam,
    module.storage,
    module.workflows,
  ]
}

# --------------------------------------------------------------------------- #
# Alerting — workflow failure email + billing budget
# --------------------------------------------------------------------------- #

module "alerting" {
  source = "../../modules/alerting"

  project_id         = var.project_id
  environment        = var.environment
  billing_account    = var.billing_account
  alert_email        = var.alert_email
  monthly_budget_usd = var.monthly_budget_usd

  depends_on = [
    google_project_service.apis["monitoring.googleapis.com"],
    google_project_service.apis["billingbudgets.googleapis.com"],
  ]
}

# --------------------------------------------------------------------------- #
# Outputs
# --------------------------------------------------------------------------- #

output "lakehouse_bucket" {
  value = module.storage.bucket_url
}

output "artifact_registry_url" {
  value = module.artifact_registry.repository_url
}

output "spark_image_base" {
  value = module.artifact_registry.spark_image_base
}

output "downloader_image_base" {
  value = module.artifact_registry.downloader_image_base
}

output "service_account_emails" {
  value = {
    downloader   = module.iam.downloader_sa_email
    pipeline     = module.iam.pipeline_sa_email
    orchestrator = module.iam.orchestrator_sa_email
  }
}

output "downloader_job_name" {
  value = module.downloader.job_name
}

output "dataproc_subnet" {
  value = module.network.dataproc_subnet_self_link
}

output "bq_datasets" {
  value = {
    silver = module.bigquery.silver_dataset_id
    obs    = module.bigquery.obs_dataset_id
  }
}

output "workflow_name" {
  value = module.workflows.workflow_name
}

output "wif_provider" {
  description = "WIF provider resource name — set as PROD_WIF_PROVIDER GitHub secret."
  value       = module.wif.wif_provider
}

output "ci_service_account" {
  description = "CI SA email — set as PROD_CI_SERVICE_ACCOUNT GitHub secret."
  value       = module.wif.ci_service_account_email
}

output "backfill_start_date" {
  description = "Earliest date included in CI-triggered backfills (YYYY-MM-DD)."
  value       = var.backfill_start_date
}
