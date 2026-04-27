resource "google_artifact_registry_repository" "images" {
  project       = var.project_id
  location      = var.region
  repository_id = "spark"
  format        = "DOCKER"
  description   = "Container images for procurement pipeline: procurement-spark and procurement-downloader."

  cleanup_policy_dry_run = false

  cleanup_policies {
    id     = "keep-last-version"
    action = "KEEP"
    most_recent_versions {
      keep_count = 1
    }
  }

  labels = {
    environment = var.environment
    managed_by  = "terraform"
  }
}
