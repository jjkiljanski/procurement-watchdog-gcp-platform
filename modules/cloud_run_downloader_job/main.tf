################################################################################
# Cloud Run Downloader Job
#
# Executes API fetch for a single date, writing compressed JSONL to bronze_raw.
# Triggered by the dispatcher service with date parameter override.
################################################################################

resource "google_artifact_registry_repository" "pipeline" {
  count = var.create_artifact_registry ? 1 : 0

  project       = var.project_id
  location      = var.region
  repository_id = "${var.naming_prefix}-pipeline"
  format        = "DOCKER"
  description   = "Container images for procurement pipeline components."

  labels = {
    environment = var.environment
    managed_by  = "terraform"
  }
}

locals {
  ar_repo_url = var.create_artifact_registry ? (
    "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.pipeline[0].repository_id}"
  ) : var.artifact_registry_url

  downloader_image = "${local.ar_repo_url}/downloader:${var.image_tag}"
}

resource "google_cloud_run_v2_job" "downloader" {
  name     = "${var.naming_prefix}-downloader"
  project  = var.project_id
  location = var.region

  labels = {
    environment = var.environment
    component   = "downloader"
    managed_by  = "terraform"
  }

  template {
    task_count = 1

    template {
      service_account = var.downloader_sa_email
      timeout         = var.job_timeout
      max_retries     = var.max_retries

      containers {
        image = local.downloader_image

        resources {
          limits = {
            cpu    = var.cpu_limit
            memory = var.memory_limit
          }
        }

        env {
          name  = "BRONZE_RAW_BUCKET"
          value = var.bronze_raw_bucket_url
        }

        env {
          name  = "STATE_BUCKET"
          value = var.state_bucket_url
        }

        env {
          name  = "TARGET_DATE"
          value = "PLACEHOLDER"  # Overridden at execution time by dispatcher
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [
      template[0].template[0].containers[0].env,
      launch_stage,
    ]
  }
}
