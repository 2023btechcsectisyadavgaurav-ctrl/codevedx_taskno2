output "data_bucket_name" {
  description = "Name of the live data bucket."
  value       = module.data_bucket.name
}

output "backup_bucket_name" {
  description = "Name of the backup bucket (second region)."
  value       = module.backup_bucket.name
}

output "data_bucket_url" {
  description = "gs:// URL of the live data bucket."
  value       = module.data_bucket.url
}

output "backup_bucket_url" {
  description = "gs:// URL of the backup bucket."
  value       = module.backup_bucket.url
}

output "backup_job_name" {
  description = "Storage Transfer job that performs the scheduled backups."
  value       = module.backup.job_name
}

output "backup_interval_hours" {
  description = "Hours between automated backups (recovery point objective)."
  value       = module.backup.interval_hours
}

output "object_hierarchy" {
  description = "Top-level folders created in the data bucket from sample-data/."
  value       = sort(distinct([for f in local.sample_files : dirname(f)]))
}

output "service_accounts" {
  description = "Least-privilege service accounts."
  value = {
    writer  = module.iam.writer_email
    reader  = module.iam.reader_email
    restore = module.iam.restore_email
  }
}

output "kms_keys" {
  description = "Customer-managed encryption keys (empty when enable_cmek is false)."
  value = var.enable_cmek ? {
    data_bucket   = module.encryption[0].primary_key_id
    backup_bucket = module.encryption[0].backup_key_id
  } : {}
}

# Exposed so the automated tests (tests/*.tftest.hcl) can assert on the design at plan time.
output "design_summary" {
  description = "Security, reliability and cost settings, asserted by the test suite."
  value = {
    data_location         = module.data_bucket.location
    backup_location       = module.backup_bucket.location
    data_class            = module.data_bucket.storage_class
    backup_class          = module.backup_bucket.storage_class
    data_transitions      = module.data_bucket.class_transitions
    backup_transitions    = module.backup_bucket.class_transitions
    public_access         = [module.data_bucket.public_access_prevention, module.backup_bucket.public_access_prevention]
    uniform_access        = [module.data_bucket.uniform_bucket_level_access, module.backup_bucket.uniform_bucket_level_access]
    versioning            = [module.data_bucket.versioning_enabled, module.backup_bucket.versioning_enabled]
    soft_delete_seconds   = [module.data_bucket.soft_delete_seconds, module.backup_bucket.soft_delete_seconds]
    cmek                  = [module.data_bucket.cmek_enabled, module.backup_bucket.cmek_enabled]
    audit_logging         = var.enable_audit_logs
    backup_interval_hours = module.backup.interval_hours
  }
}
