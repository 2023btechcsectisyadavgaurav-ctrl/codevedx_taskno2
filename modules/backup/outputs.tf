output "job_name" {
  description = "Name of the transfer job (transferJobs/...), usable with `gcloud transfer jobs run`."
  value       = google_storage_transfer_job.backup.name
}

output "interval_hours" {
  description = "Hours between backups (the recovery point objective)."
  value       = var.interval_hours
}
