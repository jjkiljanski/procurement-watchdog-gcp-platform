################################################################################
# Workflows Module — Cloud Workflows + Cloud Scheduler
#
# Provisions:
#   - Cloud Workflows workflow (daily pipeline: download → bronze → silver → deltas)
#   - Cloud Scheduler job (triggers the workflow daily at var.schedule_cron)
#   - Scheduler invoker service account + roles/workflows.invoker binding
#
# The workflow YAML is rendered from templates/daily_pipeline.yaml.tpl at
# terraform apply time. Static config (project, bucket, SAs, etc.) is baked
# in; only target_date is a runtime arg (defaults to yesterday).
################################################################################

locals {
  daily_workflow_source = templatefile("${path.module}/templates/daily_pipeline.yaml.tpl", {
    project_id                = var.project_id
    region                    = var.region
    lakehouse_bucket          = var.lakehouse_bucket
    pipeline_sa_email         = var.pipeline_sa_email
    dataproc_subnet_self_link = var.dataproc_subnet_self_link
    dataproc_container_image  = var.dataproc_container_image
    downloader_job_name       = var.downloader_job_name
    bq_silver_dataset_id      = var.bq_silver_dataset_id
    bq_obs_dataset_id         = var.bq_obs_dataset_id
    workflow_name             = "${var.naming_prefix}-daily-pipeline"
  })
}

# --------------------------------------------------------------------------- #
# Cloud Workflows — Daily Pipeline
# --------------------------------------------------------------------------- #

resource "google_workflows_workflow" "daily" {
  name            = "${var.naming_prefix}-daily-pipeline"
  project         = var.project_id
  region          = var.region
  service_account = var.orchestrator_sa_email
  description     = "Daily BZP pipeline: download → bronze → silver → deltas."
  source_contents = local.daily_workflow_source

  labels = {
    environment = var.environment
    managed_by  = "terraform"
  }
}

# --------------------------------------------------------------------------- #
# Cloud Scheduler Invoker SA
# --------------------------------------------------------------------------- #

resource "google_service_account" "scheduler_invoker" {
  project      = var.project_id
  account_id   = "${var.naming_prefix}-sched-invoke"
  display_name = "Cloud Scheduler Invoker SA"
  description  = "Identity used by Cloud Scheduler to trigger Cloud Workflows executions."
}

resource "google_workflows_workflow_iam_member" "scheduler_can_invoke" {
  project  = var.project_id
  location = var.region
  workflow = google_workflows_workflow.daily.name
  role     = "roles/workflows.invoker"
  member   = "serviceAccount:${google_service_account.scheduler_invoker.email}"
}

# --------------------------------------------------------------------------- #
# Cloud Scheduler — Daily Trigger
# --------------------------------------------------------------------------- #

resource "google_cloud_scheduler_job" "daily" {
  name        = "${var.naming_prefix}-daily-pipeline"
  project     = var.project_id
  region      = var.region
  description = "Triggers the daily BZP pipeline workflow."
  schedule    = var.schedule_cron
  time_zone   = var.time_zone

  http_target {
    http_method = "POST"
    uri         = "https://workflowexecutions.googleapis.com/v1/${google_workflows_workflow.daily.id}/executions"
    # Empty argument — workflow defaults target_date to yesterday
    body        = base64encode(jsonencode({ argument = "{}" }))

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
