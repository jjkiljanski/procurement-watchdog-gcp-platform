################################################################################
# Dataproc Permissions Module
#
# Grants the pipeline runtime service account permissions required to run
# Dataproc Serverless Spark batch jobs. Does NOT create static batch
# definitions — those are submitted dynamically by the launcher service.
################################################################################

# Pipeline SA needs Dataproc Worker role to run as the batch identity.
resource "google_project_iam_member" "pipeline_dataproc_worker" {
  project = var.project_id
  role    = "roles/dataproc.worker"
  member  = "serviceAccount:${var.pipeline_runtime_sa_email}"
}

# BigQuery Data Editor — required if Spark writes to BigQuery (optional path).
resource "google_project_iam_member" "pipeline_bigquery_editor" {
  count = var.enable_bigquery_access ? 1 : 0

  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${var.pipeline_runtime_sa_email}"
}

# Logging write — Dataproc Serverless needs to ship logs.
resource "google_project_iam_member" "pipeline_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${var.pipeline_runtime_sa_email}"
}

# Monitoring metric writer — Dataproc Serverless metrics.
resource "google_project_iam_member" "pipeline_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${var.pipeline_runtime_sa_email}"
}
