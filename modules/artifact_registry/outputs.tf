output "repository_url" {
  description = "Base URL for the Docker repository (without image name or tag)."
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.images.repository_id}"
}

output "spark_image_base" {
  description = "Base path for the procurement-spark image. Append :<tag> to form a full image URI."
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.images.repository_id}/procurement-spark"
}

output "downloader_image_base" {
  description = "Base path for the procurement-downloader image. Append :<tag> to form a full image URI."
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.images.repository_id}/procurement-downloader"
}
