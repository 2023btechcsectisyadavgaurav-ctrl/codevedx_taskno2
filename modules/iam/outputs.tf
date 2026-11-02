output "writer_email" {
  description = "Service account that writes application data."
  value       = google_service_account.writer.email
}

output "reader_email" {
  description = "Service account with read-only access."
  value       = google_service_account.reader.email
}

output "restore_email" {
  description = "Service account used to restore data from the backup bucket."
  value       = google_service_account.restore.email
}
