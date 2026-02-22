################################################################################
# IAM Module — Service Accounts & Bucket-Level Bindings
#
# Creates dedicated service accounts for each component with least-privilege
# bucket-level IAM. No project-level editor/owner roles.
################################################################################

# --------------------------------------------------------------------------- #
# Service Accounts
# --------------------------------------------------------------------------- #

resource "google_service_account" "downloader" {
  project      = var.project_id
  account_id   = "${var.naming_prefix}-downloader"
  display_name = "Downloader Cloud Run Job SA"
  description  = "Fetches API data and writes to bronze_raw + state buckets."
}

resource "google_service_account" "dispatcher" {
  project      = var.project_id
  account_id   = "${var.naming_prefix}-dispatcher"
  display_name = "Dispatcher Cloud Run Service SA"
  description  = "Reads state bucket and launches downloader jobs."
}

resource "google_service_account" "pipeline_runtime" {
  project      = var.project_id
  account_id   = "${var.naming_prefix}-pipeline-rt"
  display_name = "Pipeline Runtime SA (Dataproc Serverless)"
  description  = "Runs Spark transforms: reads bronze_raw, writes bronze/silver/gold."
}

resource "google_service_account" "launcher" {
  project      = var.project_id
  account_id   = "${var.naming_prefix}-launcher"
  display_name = "Launcher Cloud Run Service SA"
  description  = "Triggers Dataproc Serverless batch jobs."
}

resource "google_service_account" "scheduler_invoker" {
  project      = var.project_id
  account_id   = "${var.naming_prefix}-sched-invoke"
  display_name = "Cloud Scheduler Invoker SA"
  description  = "Identity used by Cloud Scheduler to invoke Cloud Run services."
}

# --------------------------------------------------------------------------- #
# Bucket-Level IAM — Downloader
# --------------------------------------------------------------------------- #

resource "google_storage_bucket_iam_member" "downloader_bronze_raw_writer" {
  bucket = var.bucket_names["bronze_raw"]
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.downloader.email}"
}

resource "google_storage_bucket_iam_member" "downloader_state_writer" {
  bucket = var.bucket_names["state"]
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.downloader.email}"
}

# --------------------------------------------------------------------------- #
# Bucket-Level IAM — Dispatcher
# --------------------------------------------------------------------------- #

resource "google_storage_bucket_iam_member" "dispatcher_state_reader" {
  bucket = var.bucket_names["state"]
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.dispatcher.email}"
}

# --------------------------------------------------------------------------- #
# Bucket-Level IAM — Pipeline Runtime (Dataproc Serverless)
# --------------------------------------------------------------------------- #

resource "google_storage_bucket_iam_member" "pipeline_bronze_raw_reader" {
  bucket = var.bucket_names["bronze_raw"]
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.pipeline_runtime.email}"
}

resource "google_storage_bucket_iam_member" "pipeline_bronze_admin" {
  bucket = var.bucket_names["bronze"]
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.pipeline_runtime.email}"
}

resource "google_storage_bucket_iam_member" "pipeline_silver_admin" {
  bucket = var.bucket_names["silver"]
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.pipeline_runtime.email}"
}

resource "google_storage_bucket_iam_member" "pipeline_gold_admin" {
  bucket = var.bucket_names["gold"]
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.pipeline_runtime.email}"
}

resource "google_storage_bucket_iam_member" "pipeline_state_admin" {
  bucket = var.bucket_names["state"]
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.pipeline_runtime.email}"
}

resource "google_storage_bucket_iam_member" "pipeline_artifacts_reader" {
  bucket = var.bucket_names["artifacts"]
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.pipeline_runtime.email}"
}

# --------------------------------------------------------------------------- #
# Bucket-Level IAM — Launcher
# --------------------------------------------------------------------------- #

resource "google_storage_bucket_iam_member" "launcher_artifacts_reader" {
  bucket = var.bucket_names["artifacts"]
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.launcher.email}"
}

# --------------------------------------------------------------------------- #
# Cloud Run Invoker — Scheduler → Dispatcher / Launcher
# --------------------------------------------------------------------------- #

resource "google_cloud_run_v2_service_iam_member" "scheduler_invokes_dispatcher" {
  count = var.dispatcher_service_name != "" ? 1 : 0

  project  = var.project_id
  location = var.region
  name     = var.dispatcher_service_name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.scheduler_invoker.email}"
}

resource "google_cloud_run_v2_service_iam_member" "scheduler_invokes_launcher" {
  count = var.launcher_service_name != "" ? 1 : 0

  project  = var.project_id
  location = var.region
  name     = var.launcher_service_name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.scheduler_invoker.email}"
}

# --------------------------------------------------------------------------- #
# Dispatcher → Cloud Run Job execution
# --------------------------------------------------------------------------- #

resource "google_project_iam_member" "dispatcher_run_developer" {
  project = var.project_id
  role    = "roles/run.developer"
  member  = "serviceAccount:${google_service_account.dispatcher.email}"
}

resource "google_service_account_iam_member" "dispatcher_acts_as_downloader" {
  service_account_id = google_service_account.downloader.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.dispatcher.email}"
}

# --------------------------------------------------------------------------- #
# Launcher → Dataproc Serverless batch submission
# --------------------------------------------------------------------------- #

resource "google_project_iam_member" "launcher_dataproc_editor" {
  project = var.project_id
  role    = "roles/dataproc.editor"
  member  = "serviceAccount:${google_service_account.launcher.email}"
}

resource "google_service_account_iam_member" "launcher_acts_as_pipeline" {
  service_account_id = google_service_account.pipeline_runtime.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.launcher.email}"
}
