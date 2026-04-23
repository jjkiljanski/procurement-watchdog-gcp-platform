output "downloader_sa_email" {
  description = "Downloader Cloud Run service account email."
  value       = google_service_account.downloader.email
}

output "pipeline_sa_email" {
  description = "Pipeline runtime (Dataproc Serverless) service account email."
  value       = google_service_account.pipeline.email
}

output "orchestrator_sa_email" {
  description = "Workflow orchestrator (Cloud Workflows) service account email."
  value       = google_service_account.orchestrator.email
}
