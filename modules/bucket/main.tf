# Reusable hardened bucket: used once for live data and once for backups.
resource "google_storage_bucket" "this" {
  name          = var.name
  project       = var.project_id
  location      = var.location
  storage_class = var.storage_class
  force_destroy = var.force_destroy
  labels        = var.labels

  # Access control: IAM only (no per-object ACLs) and never public.
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  # Reliability: keep old versions, and keep deleted objects recoverable for a while.
  versioning {
    enabled = var.versioning
  }

  soft_delete_policy {
    retention_duration_seconds = var.soft_delete_days * 86400
  }

  # Security: customer-managed encryption key (Cloud KMS), when enabled.
  dynamic "encryption" {
    for_each = var.enable_cmek ? [1] : []

    content {
      default_kms_key_name = var.kms_key_name
    }
  }

  # Cost: storage-class transitions and old-version cleanup.
  dynamic "lifecycle_rule" {
    for_each = var.lifecycle_rules

    content {
      action {
        type          = lifecycle_rule.value.action.type
        storage_class = lifecycle_rule.value.action.storage_class
      }

      condition {
        age                        = lifecycle_rule.value.condition.age
        matches_storage_class      = lifecycle_rule.value.condition.matches_storage_class
        days_since_noncurrent_time = lifecycle_rule.value.condition.days_since_noncurrent_time
        num_newer_versions         = lifecycle_rule.value.condition.num_newer_versions
      }
    }
  }
}
