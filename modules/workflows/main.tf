################################################################################
# Workflows Module — Cloud Workflows + Cloud Scheduler
#
# Provisions:
#   - Cloud Workflows workflow (daily pipeline: download → bronze → silver → deltas)
#   - Cloud Scheduler job (triggers the workflow daily at var.schedule_cron)
#   - Scheduler invoker service account + roles/workflows.invoker binding
#
# The workflow YAML source lives in the lakehouse repo (workflows/daily.yaml)
# and is deployed there via:
#   gcloud workflows deploy bzp-daily --source workflows/daily.yaml ...
#
# Terraform manages the resource, IAM, and scheduler but does NOT overwrite
# the YAML source on apply (ignore_changes = [source_contents]).
# The scheduler passes all pipeline config as runtime args so the YAML stays
# environment-agnostic and the lakehouse repo remains the single source of truth.
################################################################################

locals {
  # All config the workflow needs at runtime — passed as the scheduler argument.
  scheduler_args = jsonencode({
    project             = var.project_id
    region              = var.region
    bucket              = var.lakehouse_bucket
    container_image     = var.dataproc_container_image
    subnet              = var.dataproc_subnet_self_link
    jobs_prefix         = "gs://${var.lakehouse_bucket}/jobs"
    downloader_job_name = var.downloader_job_name
  })
}

# --------------------------------------------------------------------------- #
# Cloud Workflows — Daily Pipeline
# --------------------------------------------------------------------------- #

resource "google_workflows_workflow" "daily" {
  name            = "bzp-daily"
  project         = var.project_id
  region          = var.region
  service_account = var.orchestrator_sa_email
  description     = "Daily BZP pipeline: download → bronze → silver → deltas."

  # Placeholder so the resource can be created on first apply.
  # The real YAML is deployed from workflows/daily.yaml in the lakehouse repo:
  #   gcloud workflows deploy bzp-daily --source workflows/daily.yaml --location REGION --service-account SA
  source_contents = "main:\n  steps:\n    - init:\n        return: placeholder"

  labels = {
    environment = var.environment
    managed_by  = "terraform"
  }

  lifecycle {
    # YAML source is owned by the lakehouse repo — gcloud workflows deploy updates it.
    ignore_changes = [source_contents]
  }
}

# --------------------------------------------------------------------------- #
# Cloud Scheduler Invoker SA
# --------------------------------------------------------------------------- #

resource "google_service_account" "scheduler_invoker" {
  project      = var.project_id
  account_id   = "${var.naming_prefix}-sched-invoke"
  display_name = "Cloud Scheduler → Workflows Invoker SA"
  description  = "Identity used by Cloud Scheduler to trigger the bzp-daily Cloud Workflows execution."
}

resource "google_project_iam_member" "scheduler_invoker_workflows" {
  project = var.project_id
  role    = "roles/workflows.invoker"
  member  = "serviceAccount:${google_service_account.scheduler_invoker.email}"
}

# --------------------------------------------------------------------------- #
# Cloud Scheduler — Daily Trigger
# --------------------------------------------------------------------------- #

resource "google_cloud_scheduler_job" "daily" {
  name        = "bzp-daily-trigger"
  project     = var.project_id
  region      = var.region
  description = "Triggers the bzp-daily Cloud Workflows execution at the configured cron schedule."
  schedule    = var.schedule_cron
  time_zone   = var.time_zone

  http_target {
    http_method = "POST"
    uri         = "https://workflowexecutions.googleapis.com/v1/${google_workflows_workflow.daily.id}/executions"
    body        = base64encode(jsonencode({ argument = local.scheduler_args }))

    oauth_token {
      service_account_email = google_service_account.scheduler_invoker.email
    }
  }

  retry_config {
    retry_count          = 1
    min_backoff_duration = "30s"
    max_backoff_duration = "120s"
  }
}
