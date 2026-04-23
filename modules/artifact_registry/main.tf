resource "google_artifact_registry_repository" "images" {
  project       = var.project_id
  location      = var.region
  repository_id = "spark"
  format        = "DOCKER"
  description   = "Container images for procurement pipeline: procurement-spark and procurement-downloader."

  labels = {
    environment = var.environment
    managed_by  = "terraform"
  }
}
