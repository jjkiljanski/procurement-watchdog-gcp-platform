################################################################################
# WIF Module — Workload Identity Federation for GitHub Actions
#
# Creates:
#   - Workload Identity Pool + GitHub OIDC provider
#   - CI service account with all permissions needed by the deploy pipeline
#   - IAM binding: GitHub Actions jobs from var.github_repo can impersonate the CI SA
#
# The CI SA permissions cover:
#   - Artifact Registry: push images
#   - GCS: upload pipeline scripts to lakehouse bucket
#   - Cloud Run: update downloader job image
#   - Cloud Workflows: deploy workflow YAML, invoke executions (backfill)
#   - Cloud Scheduler: update scheduler message body (new container image)
#   - BigQuery: create/update external table definitions
#   - IAM: act as orchestrator SA when deploying workflows
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
# Bucket-Level IAM — upload pipeline scripts
# --------------------------------------------------------------------------- #

resource "google_storage_bucket_iam_member" "ci_scripts_writer" {
  bucket = var.lakehouse_bucket
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.ci.email}"
}

# --------------------------------------------------------------------------- #
# SA-Level IAM — CI acts as orchestrator SA when deploying Cloud Workflows
# (gcloud workflows deploy --service-account=orchestrator_sa requires this)
# --------------------------------------------------------------------------- #

resource "google_service_account_iam_member" "ci_acts_as_orchestrator" {
  service_account_id = var.orchestrator_sa_id
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.ci.email}"
}

# `gcloud run jobs update` requires actAs on the job's runtime SA.
resource "google_service_account_iam_member" "ci_acts_as_downloader" {
  service_account_id = var.downloader_sa_id
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.ci.email}"
}

# `gcloud scheduler jobs update http` requires actAs on the scheduler's invoker SA.
resource "google_service_account_iam_member" "ci_acts_as_scheduler_invoker" {
  service_account_id = var.scheduler_invoker_sa_id
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.ci.email}"
}
