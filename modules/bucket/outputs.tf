output "name" {
  description = "Bucket name."
  value       = google_storage_bucket.this.name
}

output "url" {
  description = "gs:// URL of the bucket."
  value       = google_storage_bucket.this.url
}

output "location" {
  description = "Bucket location."
  value       = google_storage_bucket.this.location
}

output "storage_class" {
  description = "Default storage class."
  value       = google_storage_bucket.this.storage_class
}

output "versioning_enabled" {
  description = "Whether object versioning is on."
  value       = google_storage_bucket.this.versioning[0].enabled
}

output "public_access_prevention" {
  description = "Public access prevention setting."
  value       = google_storage_bucket.this.public_access_prevention
}

output "uniform_bucket_level_access" {
  description = "Whether uniform bucket-level access is on."
  value       = google_storage_bucket.this.uniform_bucket_level_access
}

output "soft_delete_seconds" {
  description = "Soft delete retention in seconds."
  value       = google_storage_bucket.this.soft_delete_policy[0].retention_duration_seconds
}

output "cmek_enabled" {
  description = "Whether a customer-managed encryption key is configured."
  value       = length(google_storage_bucket.this.encryption) > 0
}

output "class_transitions" {
  description = "Storage classes this bucket's lifecycle moves objects into."
  value = [
    for rule in google_storage_bucket.this.lifecycle_rule : one(rule.action).storage_class
    if one(rule.action).type == "SetStorageClass"
  ]
}
