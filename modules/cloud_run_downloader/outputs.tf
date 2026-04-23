output "job_name" {
  description = "Cloud Run Job name (use as downloader_job_name Airflow Variable)."
  value       = google_cloud_run_v2_job.downloader.name
}

output "job_id" {
  description = "Fully qualified Cloud Run Job resource ID."
  value       = google_cloud_run_v2_job.downloader.id
}
