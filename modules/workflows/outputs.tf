output "workflow_name" {
  description = "Cloud Workflows workflow name."
  value       = google_workflows_workflow.daily.name
}

output "workflow_id" {
  description = "Fully qualified workflow resource ID."
  value       = google_workflows_workflow.daily.id
}

output "scheduler_job_name" {
  description = "Cloud Scheduler job name."
  value       = google_cloud_scheduler_job.daily.name
}

output "scheduler_invoker_sa_id" {
  description = "Full resource ID of the scheduler invoker SA (projects/…/serviceAccounts/…)."
  value       = google_service_account.scheduler_invoker.name
}
