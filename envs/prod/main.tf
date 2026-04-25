################################################################################
# Main Composition — Prod Environment
#
# Identical module structure to dev. Differences: force_destroy=false on
# storage, larger downloader container, pinned image tags.
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
    "artifactregistry.googleapis.com",
    "bigquery.googleapis.com",
    "logging.googleapis.com",
    "compute.googleapis.com",
    "workflows.googleapis.com",
    "workflowexecutions.googleapis.com",
    "cloudscheduler.googleapis.com",
  ]
}

resource "google_project_service" "apis" {
  for_each = toset(local.required_apis)

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# --------------------------------------------------------------------------- #
# Storage — single unified lakehouse bucket
# --------------------------------------------------------------------------- #

module "storage" {
  source = "../../modules/storage"

  project_id      = var.project_id
  environment     = var.environment
  bucket_location = var.bucket_location
  force_destroy   = false

  depends_on = [google_project_service.apis]
}

# --------------------------------------------------------------------------- #
# Network — subnet with Private Google Access for Dataproc Serverless
# --------------------------------------------------------------------------- #

module "network" {
  source = "../../modules/network"

  project_id    = var.project_id
  region        = var.region
  naming_prefix = var.naming_prefix
  network_name  = var.network_name
  subnet_cidr   = var.dataproc_subnet_cidr

  depends_on = [google_project_service.apis]
}

# --------------------------------------------------------------------------- #
# Artifact Registry — Docker repository for Spark + downloader images
# --------------------------------------------------------------------------- #

module "artifact_registry" {
  source = "../../modules/artifact_registry"

  project_id  = var.project_id
  region      = var.region
  environment = var.environment

  depends_on = [google_project_service.apis]
}

# --------------------------------------------------------------------------- #
# IAM — service accounts and bindings
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

  project_id            = var.project_id
  region                = var.region
  environment           = var.environment
  downloader_sa_email   = module.iam.downloader_sa_email
  lakehouse_bucket      = module.storage.bucket_name
  bq_obs_dataset_id     = var.bq_obs_dataset_id
  cpu_limit             = "2"
  memory_limit          = "2Gi"

  depends_on = [module.iam, module.artifact_registry]
}

# --------------------------------------------------------------------------- #
# BigQuery — procurement_silver and procurement_obs datasets
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
# Workflows — daily pipeline + Cloud Scheduler trigger
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
  dataproc_container_image  = var.dataproc_container_image
  downloader_job_name       = module.downloader.job_name
  bq_silver_dataset_id      = var.bq_silver_dataset_id
  bq_obs_dataset_id         = var.bq_obs_dataset_id
  schedule_cron             = var.schedule_cron
  time_zone                 = var.time_zone

  depends_on = [module.iam, module.network, module.storage, module.downloader]
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
