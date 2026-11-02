variable "project_id" {
  description = "GCP project ID that will hold every resource."
  type        = string
}

variable "region" {
  description = "Region of the primary data bucket and its encryption key."
  type        = string
  default     = "us-central1"
}

variable "backup_region" {
  description = "Region of the backup bucket. Must differ from `region` so a regional outage cannot take out both copies."
  type        = string
  default     = "us-east1"

  validation {
    condition     = var.backup_region != var.region
    error_message = "backup_region must be different from region (disaster recovery needs a second region)."
  }
}

variable "environment" {
  description = "Environment name, used in resource names and labels."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "name_prefix" {
  description = "Prefix for all resource names (3-12 chars: lowercase letters, digits, hyphens)."
  type        = string
  default     = "cloudstore"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,11}$", var.name_prefix))
    error_message = "name_prefix must start with a letter, be 3-12 characters, and use only lowercase letters, digits and hyphens."
  }
}

# ---------------------------------------------------------------------------
# Security
# ---------------------------------------------------------------------------
variable "enable_cmek" {
  description = "Encrypt both buckets with customer-managed keys (Cloud KMS) instead of Google-managed keys."
  type        = bool
  default     = true
}

variable "kms_rotation_days" {
  description = "Automatic rotation period of the encryption keys, in days."
  type        = number
  default     = 90

  validation {
    condition     = var.kms_rotation_days >= 1 && var.kms_rotation_days <= 365
    error_message = "kms_rotation_days must be between 1 and 365."
  }
}

variable "enable_audit_logs" {
  description = "Write Cloud Audit data-access logs for Cloud Storage (who read, wrote or deleted what)."
  type        = bool
  default     = true
}

variable "reader_members" {
  description = "IAM members with read-only access to the data bucket, e.g. [\"user:someone@example.com\"]."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for m in var.reader_members : can(regex("^(user|group|serviceAccount):[^ ]+$", m))])
    error_message = "Members must look like user:..., group:... or serviceAccount:... (public principals such as allUsers are not allowed)."
  }
}

variable "writer_members" {
  description = "IAM members who may read and write objects in the data bucket."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for m in var.writer_members : can(regex("^(user|group|serviceAccount):[^ ]+$", m))])
    error_message = "Members must look like user:..., group:... or serviceAccount:... (public principals such as allUsers are not allowed)."
  }
}

variable "admin_members" {
  description = "IAM members with full control of both buckets (backup administrators)."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for m in var.admin_members : can(regex("^(user|group|serviceAccount):[^ ]+$", m))])
    error_message = "Members must look like user:..., group:... or serviceAccount:... (public principals such as allUsers are not allowed)."
  }
}

# ---------------------------------------------------------------------------
# Reliability: versioning, soft delete, backups
# ---------------------------------------------------------------------------
variable "soft_delete_days" {
  description = "Days a deleted object stays recoverable (soft delete). 0 disables it; otherwise 7-90."
  type        = number
  default     = 7

  validation {
    condition     = var.soft_delete_days == 0 || (var.soft_delete_days >= 7 && var.soft_delete_days <= 90)
    error_message = "soft_delete_days must be 0 (off) or between 7 and 90."
  }
}

variable "noncurrent_retention_days" {
  description = "Days old (overwritten or deleted) object versions are kept before being removed."
  type        = number
  default     = 30

  validation {
    condition     = var.noncurrent_retention_days >= 1
    error_message = "noncurrent_retention_days must be at least 1."
  }
}

variable "max_noncurrent_versions" {
  description = "Maximum number of old versions kept per object in the data bucket."
  type        = number
  default     = 5

  validation {
    condition     = var.max_noncurrent_versions >= 1
    error_message = "max_noncurrent_versions must be at least 1."
  }
}

variable "backup_interval_hours" {
  description = "How often the automated backup job copies new and changed objects to the backup bucket (this is your RPO)."
  type        = number
  default     = 24

  validation {
    condition     = var.backup_interval_hours >= 1 && var.backup_interval_hours <= 168
    error_message = "backup_interval_hours must be between 1 and 168."
  }
}

variable "backup_start_hour_utc" {
  description = "Hour of day (UTC, 0-23) at which the daily backup schedule starts."
  type        = number
  default     = 2

  validation {
    condition     = var.backup_start_hour_utc >= 0 && var.backup_start_hour_utc <= 23
    error_message = "backup_start_hour_utc must be between 0 and 23."
  }
}

# ---------------------------------------------------------------------------
# Cost: storage class lifecycle (days since the object was created)
# ---------------------------------------------------------------------------
variable "nearline_after_days" {
  description = "Move objects from Standard to Nearline (infrequent access, about monthly) after this many days."
  type        = number
  default     = 30

  validation {
    condition     = var.nearline_after_days >= 1
    error_message = "nearline_after_days must be at least 1."
  }
}

variable "coldline_after_days" {
  description = "Move objects from Nearline to Coldline (rare access, about quarterly) after this many days."
  type        = number
  default     = 90

  validation {
    condition     = var.coldline_after_days > var.nearline_after_days
    error_message = "coldline_after_days must be greater than nearline_after_days."
  }
}

variable "archive_after_days" {
  description = "Move objects from Coldline to Archive (long-term retention, about yearly access) after this many days."
  type        = number
  default     = 365

  validation {
    condition     = var.archive_after_days > var.coldline_after_days
    error_message = "archive_after_days must be greater than coldline_after_days."
  }
}

# ---------------------------------------------------------------------------
# Housekeeping
# ---------------------------------------------------------------------------
variable "upload_sample_data" {
  description = "Upload the files in sample-data/ so the bucket hierarchy and the demo have content."
  type        = bool
  default     = true
}

variable "force_destroy" {
  description = "Allow `terraform destroy` to delete buckets even when they contain objects."
  type        = bool
  default     = true
}

variable "extra_labels" {
  description = "Additional labels applied to every resource that supports labels."
  type        = map(string)
  default     = {}
}
