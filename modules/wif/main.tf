################################################################################
# WIF Module — Workload Identity Federation for GitHub Actions
#
# Creates:
#   - Workload Identity Pool + GitHub OIDC provider
#   - CI service account with all permissions needed by the deploy pipeline
#   - IAM binding: GitHub Actions jobs from var.github_repo can impersonate the CI SA
#
# Permission inventory (why each role is required)
# ------------------------------------------------
# roles/artifactregistry.writer
#   `docker push` to the Artifact Registry repos for the Spark and downloader images.
#
# roles/run.developer
#   `gcloud run jobs update` to swap the container image on the bzp-downloader Cloud Run job.
#
# roles/workflows.editor
#   `gcloud workflows deploy` to upload updated bzp-daily and bzp-backfill YAML definitions.
#
# roles/workflows.invoker
#   `gcloud workflows run` to trigger the bzp-backfill execution on release tags.
#
# roles/cloudscheduler.admin
#   `gcloud scheduler jobs update http` to refresh the message body (container_image field)
#   in the bzp-daily-trigger scheduler job after each image push.
#
# roles/bigquery.dataEditor
#   `setup_bq_external_tables.py` creates/replaces external Iceberg table definitions
#   in the procurement_silver and procurement_obs datasets.
#
# roles/bigquery.jobUser
#   Required alongside dataEditor to actually run the BigQuery jobs that the setup
#   script submits (GCP splits table-level access from job-submission access).
#
# roles/storage.objectAdmin (bucket-level)
#   `gsutil cp scripts/pipeline/*.py gs://{bucket}/jobs/` uploads the pipeline scripts
#   that Dataproc Serverless reads at batch submission time.
#
# roles/iam.serviceAccountUser on orchestrator SA
#   `gcloud workflows deploy --service-account=orchestrator_sa` — GCP requires the
#   caller to be able to actAs any SA it assigns to a resource it is creating/updating.
#
# roles/iam.serviceAccountUser on downloader SA
#   `gcloud run jobs update` on bzp-downloader — even without an explicit
#   --service-account flag, GCP validates the caller can actAs the SA already
#   attached to the Cloud Run job.
#
# roles/iam.serviceAccountUser on scheduler invoker SA
#   `gcloud scheduler jobs update http` on bzp-daily-trigger — same rule as above:
#   GCP validates the caller can actAs the SA already attached to the scheduler job.
################################################################################

resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = "${var.naming_prefix}-github-pool"
  display_name              = "GitHub Actions"
  description               = "Allows GitHub Actions jobs in ${var.github_repo} to authenticate without SA keys."
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "${var.naming_prefix}-github"
  display_name                       = "GitHub Actions OIDC"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }

  attribute_condition = "assertion.repository == '${var.github_repo}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# --------------------------------------------------------------------------- #
# CI Service Account
# --------------------------------------------------------------------------- #

resource "google_service_account" "ci" {
  project      = var.project_id
  account_id   = "${var.naming_prefix}-ci"
  display_name = "CI/CD Service Account (GitHub Actions)"
  description  = "Impersonated by GitHub Actions via WIF. Manages images, scripts, workflows, and scheduler."
}

# Allow any job in the configured repo to impersonate this SA.
resource "google_service_account_iam_member" "wif_impersonation" {
  service_account_id = google_service_account.ci.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repo}"
}

# --------------------------------------------------------------------------- #
# Project-Level IAM for CI SA
# (see permission inventory in the module header for the "why" of each role)
# --------------------------------------------------------------------------- #

resource "google_project_iam_member" "ci_ar_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.ci.email}"
}

resource "google_project_iam_member" "ci_run_developer" {
  project = var.project_id
  role    = "roles/run.developer"
  member  = "serviceAccount:${google_service_account.ci.email}"
}

resource "google_project_iam_member" "ci_workflows_editor" {
  project = var.project_id
  role    = "roles/workflows.editor"
  member  = "serviceAccount:${google_service_account.ci.email}"
}

resource "google_project_iam_member" "ci_workflows_invoker" {
  project = var.project_id
  role    = "roles/workflows.invoker"
  member  = "serviceAccount:${google_service_account.ci.email}"
}

resource "google_project_iam_member" "ci_scheduler_admin" {
  project = var.project_id
  role    = "roles/cloudscheduler.admin"
  member  = "serviceAccount:${google_service_account.ci.email}"
}

resource "google_project_iam_member" "ci_bq_data_editor" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.ci.email}"
}

resource "google_project_iam_member" "ci_bq_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.ci.email}"
}

# --------------------------------------------------------------------------- #
# Bucket-Level IAM
# --------------------------------------------------------------------------- #

resource "google_storage_bucket_iam_member" "ci_scripts_writer" {
  bucket = var.lakehouse_bucket
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.ci.email}"
}

# --------------------------------------------------------------------------- #
# SA-Level IAM (actAs bindings)
# GCP requires iam.serviceaccounts.actAs whenever a gcloud command assigns or
# inherits a service account on a resource — even when no --service-account
# flag is passed explicitly (the SA already attached to the resource is checked).
# --------------------------------------------------------------------------- #

resource "google_service_account_iam_member" "ci_acts_as_orchestrator" {
  service_account_id = var.orchestrator_sa_id
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.ci.email}"
}

resource "google_service_account_iam_member" "ci_acts_as_downloader" {
  service_account_id = var.downloader_sa_id
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.ci.email}"
}

resource "google_service_account_iam_member" "ci_acts_as_scheduler_invoker" {
  service_account_id = var.scheduler_invoker_sa_id
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.ci.email}"
}
