output "backfill_scheduler_name" {
  description = "Name of the backfill Cloud Scheduler job."
  value       = google_cloud_scheduler_job.backfill.name
}

output "transformation_scheduler_name" {
  description = "Name of the transformation Cloud Scheduler job."
  value       = google_cloud_scheduler_job.transformation.name
}
