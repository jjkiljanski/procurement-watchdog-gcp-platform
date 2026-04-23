################################################################################
# Cloud Run Downloader Job — bzp-downloader
#
# Executes apps/downloader/main.py which wraps fetch_bzp_yesterday.py (or
# fetch_bzp_range.py for backfill). Triggered by Airflow daily_dag and
# backfill_dag with TARGET_DATE / START_DATE / END_DATE env overrides.
################################################################################

locals {
  image = "${var.artifact_registry_url}/procurement-downloader:${var.image_tag}"
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
          name  = "TARGET_DATE"
          value = "PLACEHOLDER"  # Overridden at execution time by Airflow DAG
        }
      }
    }
  }

  lifecycle {
    # Allow CI/CD to update the image tag and env overrides without Terraform drift
    ignore_changes = [
      template[0].template[0].containers[0].image,
      template[0].template[0].containers[0].env,
      launch_stage,
    ]
  }
}
