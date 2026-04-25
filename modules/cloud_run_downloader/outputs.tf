output "job_name" {
  description = "Cloud Run Job name (referenced by Cloud Workflows as downloader_job_name)."
  value       = google_cloud_run_v2_job.downloader.name
}

output "job_id" {
  description = "Fully qualified Cloud Run Job resource ID."
  value       = google_cloud_run_v2_job.downloader.id
}
