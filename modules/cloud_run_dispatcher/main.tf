################################################################################
# Cloud Run Dispatcher Service
#
# HTTP service triggered by Cloud Scheduler. On each invocation:
#   1. Scans state bucket for completed date markers
#   2. Determines next unprocessed date in the backfill window
#   3. Triggers downloader Cloud Run Job for that date
#   4. Respects max concurrency to avoid API overload
################################################################################

resource "google_cloud_run_v2_service" "dispatcher" {
  name     = "${var.naming_prefix}-dispatcher"
  project  = var.project_id
  location = var.region
  ingress  = "INGRESS_TRAFFIC_INTERNAL_ONLY"

  labels = {
    environment = var.environment
    component   = "dispatcher"
    managed_by  = "terraform"
  }

  template {
    service_account = var.dispatcher_sa_email

    scaling {
      min_instance_count = 0
      max_instance_count = 1
    }

    timeout = var.request_timeout

    containers {
      image = "${var.artifact_registry_url}/dispatcher:${var.image_tag}"

      resources {
        limits = {
          cpu    = var.cpu_limit
          memory = var.memory_limit
        }
      }

      env {
        name  = "STATE_BUCKET"
        value = var.state_bucket_url
      }

      env {
        name  = "DOWNLOADER_JOB_NAME"
        value = var.downloader_job_name
      }

      env {
        name  = "GCP_PROJECT"
        value = var.project_id
      }

      env {
        name  = "GCP_REGION"
        value = var.region
      }

      env {
        name  = "MAX_CONCURRENCY"
        value = tostring(var.max_backfill_concurrency)
      }

      env {
        name  = "BACKFILL_START_DATE"
        value = var.backfill_start_date
      }
    }
  }

  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
      launch_stage,
    ]
  }
}
