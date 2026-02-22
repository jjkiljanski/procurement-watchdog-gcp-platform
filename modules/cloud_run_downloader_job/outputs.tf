output "job_name" {
  description = "Cloud Run Job name for the downloader."
  value       = google_cloud_run_v2_job.downloader.name
}

output "job_id" {
  description = "Fully qualified Cloud Run Job ID."
  value       = google_cloud_run_v2_job.downloader.id
}

output "artifact_registry_url" {
  description = "Artifact Registry repository URL."
  value       = local.ar_repo_url
}
