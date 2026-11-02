output "primary_key_id" {
  description = "Resource ID of the key for the primary data bucket."
  value       = google_kms_crypto_key.primary.id
}

output "backup_key_id" {
  description = "Resource ID of the key for the backup bucket."
  value       = google_kms_crypto_key.backup.id
}

output "rotation_period" {
  description = "Key rotation period."
  value       = google_kms_crypto_key.primary.rotation_period
}
