################################################################################
# BigQuery Module — Silver and Observability Datasets
#
# Creates two datasets:
#   - procurement_silver: external Iceberg tables are created by
#     setup_bq_external_tables.py (not Terraform).
#   - procurement_obs: pipeline_runs, dq_metrics, quarantine_summary tables
#     are created automatically by obs.py on first write.
#
# Grants the pipeline SA dataEditor on both datasets so Dataproc batches can
# create and write obs tables, and so future Iceberg table registration works.
################################################################################

resource "google_bigquery_dataset" "silver" {
  dataset_id  = var.silver_dataset_id
  project     = var.project_id
  location    = var.bq_location
  description = "Silver layer — external Iceberg tables over gs://{lakehouse}/iceberg/. Tables managed by setup_bq_external_tables.py."

  labels = {
    environment = var.environment
    layer       = "silver"
    managed_by  = "terraform"
  }
}

resource "google_bigquery_dataset" "obs" {
  dataset_id  = var.obs_dataset_id
  project     = var.project_id
  location    = var.bq_location
  description = "Observability — pipeline_runs, dq_metrics, quarantine_summary. Tables created by obs.py on first write."

  labels = {
    environment = var.environment
    layer       = "obs"
    managed_by  = "terraform"
  }
}

# --------------------------------------------------------------------------- #
# Dataset-Level IAM — Pipeline SA
# --------------------------------------------------------------------------- #

resource "google_bigquery_dataset_iam_member" "pipeline_silver_editor" {
  project    = var.project_id
  dataset_id = google_bigquery_dataset.silver.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${var.pipeline_sa_email}"
}

resource "google_bigquery_dataset_iam_member" "pipeline_obs_editor" {
  project    = var.project_id
  dataset_id = google_bigquery_dataset.obs.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${var.pipeline_sa_email}"
}
