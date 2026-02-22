output "downloader_sa_email" {
  description = "Downloader service account email."
  value       = google_service_account.downloader.email
}

output "dispatcher_sa_email" {
  description = "Dispatcher service account email."
  value       = google_service_account.dispatcher.email
}

output "pipeline_runtime_sa_email" {
  description = "Pipeline runtime (Dataproc) service account email."
  value       = google_service_account.pipeline_runtime.email
}

output "launcher_sa_email" {
  description = "Launcher service account email."
  value       = google_service_account.launcher.email
}

output "scheduler_invoker_sa_email" {
  description = "Cloud Scheduler invoker service account email."
  value       = google_service_account.scheduler_invoker.email
}
