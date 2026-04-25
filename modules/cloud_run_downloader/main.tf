################################################################################
# Cloud Run Downloader Job — bzp-downloader
#
# Executes apps/downloader/main.py which wraps fetch_bzp_yesterday.py (or
# fetch_bzp_range.py for backfill). Triggered by Cloud Workflows (bzp-daily /
# bzp-backfill) with TARGET_DATE overridden per execution via containerOverrides.
################################################################################

locals {
  # Empty image_tag means the image hasn't been built yet — use a public placeholder
  # so the job resource can be created. Set image_tag in tfvars after the first build.
  image = var.image_tag == "" ? "us-docker.pkg.dev/cloudrun/container/hello:latest" : "${var.artifact_registry_url}/procurement-downloader:${var.image_tag}"
}

resource "google_cloud_run_v2_job" "downloader" {
  name     = var.job_name
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
        image = local.image

        resources {
          limits = {
            cpu    = var.cpu_limit
            memory = var.memory_limit
          }
        }

        env {
          name  = "RUNTIME_ENV"
          value = "gcp"
        }

        env {
          name  = "GCP_PROJECT"
          value = var.project_id
        }

        env {
          name  = "LAKEHOUSE_BUCKET"
          value = var.lakehouse_bucket
        }

        env {
          name  = "BQ_OBS_DATASET"
          value = var.bq_obs_dataset_id
        }

        env {
          name  = "TARGET_DATE"
          value = "PLACEHOLDER"  # Overridden at execution time via Cloud Workflows containerOverrides
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [launch_stage]
  }
}
