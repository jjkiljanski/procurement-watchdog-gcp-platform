################################################################################
# Cloud Run Launcher Service
#
# HTTP service triggered by Cloud Scheduler. Submits Dataproc Serverless
# Spark batch jobs for bronze→silver→gold transformation.
# The launcher itself does NOT run Spark — it only submits batch requests.
################################################################################

resource "google_cloud_run_v2_service" "launcher" {
  name     = "${var.naming_prefix}-launcher"
  project  = var.project_id
  location = var.region
  ingress  = "INGRESS_TRAFFIC_INTERNAL_ONLY"

  labels = {
    environment = var.environment
    component   = "launcher"
    managed_by  = "terraform"
  }

  template {
    service_account = var.launcher_sa_email

    scaling {
      min_instance_count = 0
      max_instance_count = 1
    }

    timeout = var.request_timeout

    containers {
      image = "${var.artifact_registry_url}/launcher:${var.image_tag}"

      resources {
        limits = {
          cpu    = var.cpu_limit
          memory = var.memory_limit
        }
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
        name  = "PIPELINE_SA_EMAIL"
        value = var.pipeline_runtime_sa_email
      }

      env {
        name  = "ARTIFACTS_BUCKET"
        value = var.artifacts_bucket_url
      }

      env {
        name  = "BRONZE_RAW_BUCKET"
        value = var.bronze_raw_bucket_url
      }

      env {
        name  = "BRONZE_BUCKET"
        value = var.bronze_bucket_url
      }

      env {
        name  = "SILVER_BUCKET"
        value = var.silver_bucket_url
      }

      env {
        name  = "GOLD_BUCKET"
        value = var.gold_bucket_url
      }

      env {
        name  = "STATE_BUCKET"
        value = var.state_bucket_url
      }

      dynamic "env" {
        for_each = var.spark_properties
        content {
          name  = "SPARK_${replace(upper(env.key), ".", "_")}"
          value = env.value
        }
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
