################################################################################
# Cloud Scheduler Module
#
# Creates two scheduled triggers:
#   1. Backfill scheduler → invokes Dispatcher to process next pending date
#   2. Transformation scheduler → invokes Launcher to run Spark pipelines
################################################################################

resource "google_cloud_scheduler_job" "backfill" {
  name      = "${var.naming_prefix}-backfill-${var.environment}"
  project   = var.project_id
  region    = var.region
  schedule  = var.backfill_schedule_cron
  time_zone = var.time_zone

  description = "Triggers the dispatcher to process the next pending backfill date."

  retry_config {
    retry_count          = 1
    min_backoff_duration = "10s"
    max_backoff_duration = "60s"
  }

  http_target {
    uri         = "${var.dispatcher_service_url}/trigger"
    http_method = "POST"

    oidc_token {
      service_account_email = var.scheduler_invoker_sa_email
      audience              = var.dispatcher_service_url
    }

    headers = {
      "Content-Type" = "application/json"
    }

    body = base64encode(jsonencode({
      action = "process_next"
    }))
  }
}

resource "google_cloud_scheduler_job" "transformation" {
  name      = "${var.naming_prefix}-transform-${var.environment}"
  project   = var.project_id
  region    = var.region
  schedule  = var.transformation_schedule_cron
  time_zone = var.time_zone

  description = "Triggers the launcher to submit Spark transformation batch jobs."

  retry_config {
    retry_count          = 1
    min_backoff_duration = "30s"
    max_backoff_duration = "120s"
  }

  http_target {
    uri         = "${var.launcher_service_url}/trigger"
    http_method = "POST"

    oidc_token {
      service_account_email = var.scheduler_invoker_sa_email
      audience              = var.launcher_service_url
    }

    headers = {
      "Content-Type" = "application/json"
    }

    body = base64encode(jsonencode({
      action = "run_daily_pipeline"
    }))
  }
}
