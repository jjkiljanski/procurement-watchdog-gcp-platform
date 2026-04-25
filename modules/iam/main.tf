################################################################################
# IAM Module — Service Accounts & IAM Bindings
#
# Three service accounts:
#   downloader  — Cloud Run Job identity (writes bronze_raw)
#   pipeline    — Dataproc Serverless batch identity (reads/writes lakehouse data)
#   orchestrator — Cloud Workflows identity (submits jobs, does not touch data)
################################################################################

# --------------------------------------------------------------------------- #
# Service Accounts
# --------------------------------------------------------------------------- #

resource "google_service_account" "downloader" {
  project      = var.project_id
  account_id   = "${var.naming_prefix}-downloader"
  display_name = "BZP Downloader Cloud Run SA"
  description  = "Cloud Run Job identity: fetches BZP API data, writes to gs://{lakehouse}/bronze_raw/."
}

resource "google_service_account" "pipeline" {
  project      = var.project_id
  account_id   = "${var.naming_prefix}-pipeline"
  display_name = "Pipeline Runtime SA (Dataproc Serverless)"
  description  = "Dataproc batch identity: reads bronze, writes silver/iceberg, writes BQ obs tables."
}

resource "google_service_account" "orchestrator" {
  project      = var.project_id
  account_id   = "${var.naming_prefix}-orchestrator"
  display_name = "Workflow Orchestrator SA (Cloud Workflows)"
  description  = "Cloud Workflows identity: submits Cloud Run Jobs and Dataproc batches."
}

# --------------------------------------------------------------------------- #
# Bucket-Level IAM — Downloader
# --------------------------------------------------------------------------- #

resource "google_storage_bucket_iam_member" "downloader_lakehouse_admin" {
  bucket = var.lakehouse_bucket
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.downloader.email}"
}

# --------------------------------------------------------------------------- #
# Bucket-Level IAM — Pipeline (Dataproc Serverless)
# --------------------------------------------------------------------------- #

resource "google_storage_bucket_iam_member" "pipeline_lakehouse_admin" {
  bucket = var.lakehouse_bucket
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.pipeline.email}"
}

# --------------------------------------------------------------------------- #
# Project-Level IAM — Pipeline SA
# --------------------------------------------------------------------------- #

resource "google_project_iam_member" "pipeline_dataproc_worker" {
  project = var.project_id
  role    = "roles/dataproc.worker"
  member  = "serviceAccount:${google_service_account.pipeline.email}"
}

resource "google_project_iam_member" "pipeline_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.pipeline.email}"
}

resource "google_project_iam_member" "pipeline_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.pipeline.email}"
}

resource "google_project_iam_member" "pipeline_bq_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.pipeline.email}"
}

# --------------------------------------------------------------------------- #
# Project-Level IAM — Orchestrator SA (Cloud Workflows)
# --------------------------------------------------------------------------- #

resource "google_project_iam_member" "orchestrator_run_developer" {
  project = var.project_id
  role    = "roles/run.developer"
  member  = "serviceAccount:${google_service_account.orchestrator.email}"
}

resource "google_project_iam_member" "orchestrator_dataproc_editor" {
  project = var.project_id
  role    = "roles/dataproc.editor"
  member  = "serviceAccount:${google_service_account.orchestrator.email}"
}

resource "google_project_iam_member" "orchestrator_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.orchestrator.email}"
}

# --------------------------------------------------------------------------- #
# SA-Level IAM — Orchestrator acts as Pipeline SA for Dataproc batch submissions
# (Dataproc batch requests specify service_account=pipeline_sa; orchestrator
#  needs iam.serviceaccounts.actAs on that SA to submit such batches.)
# --------------------------------------------------------------------------- #

resource "google_service_account_iam_member" "orchestrator_acts_as_pipeline" {
  service_account_id = google_service_account.pipeline.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.orchestrator.email}"
}
