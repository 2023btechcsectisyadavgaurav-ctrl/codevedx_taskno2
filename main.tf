provider "google" {
  project = var.project_id
  region  = var.region
}

locals {
  name = "${var.name_prefix}-${var.environment}"

  labels = merge(
    {
      project     = "cloud-storage-backup-management"
      environment = var.environment
      managed-by  = "terraform"
    },
    var.extra_labels,
  )

  required_apis = [
    "cloudkms.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "logging.googleapis.com",
    "storage.googleapis.com",
    "storagetransfer.googleapis.com",
  ]

  # Bucket names are global, so the project ID keeps them unique.
  data_bucket_name   = "${local.name}-data-${var.project_id}"
  backup_bucket_name = "${local.name}-backup-${var.project_id}"

  # Cost: live data cools down Standard -> Nearline -> Coldline -> Archive as it ages.
  data_lifecycle_rules = [
    {
      action    = { type = "SetStorageClass", storage_class = "NEARLINE" }
      condition = { age = var.nearline_after_days, matches_storage_class = ["STANDARD"] }
    },
    {
      action    = { type = "SetStorageClass", storage_class = "COLDLINE" }
      condition = { age = var.coldline_after_days, matches_storage_class = ["NEARLINE"] }
    },
    {
      action    = { type = "SetStorageClass", storage_class = "ARCHIVE" }
      condition = { age = var.archive_after_days, matches_storage_class = ["COLDLINE"] }
    },
    {
      action    = { type = "Delete" }
      condition = { days_since_noncurrent_time = var.noncurrent_retention_days }
    },
    {
      action    = { type = "Delete" }
      condition = { num_newer_versions = var.max_noncurrent_versions }
    },
  ]

  # Backups start in Nearline (written once, rarely read) and cool further; old versions are pruned.
  backup_lifecycle_rules = [
    {
      action    = { type = "SetStorageClass", storage_class = "COLDLINE" }
      condition = { age = var.coldline_after_days, matches_storage_class = ["NEARLINE"] }
    },
    {
      action    = { type = "SetStorageClass", storage_class = "ARCHIVE" }
      condition = { age = var.archive_after_days, matches_storage_class = ["COLDLINE"] }
    },
    {
      action    = { type = "Delete" }
      condition = { days_since_noncurrent_time = var.noncurrent_retention_days }
    },
  ]

  sample_files = var.upload_sample_data ? fileset("${path.module}/sample-data", "**") : toset([])
}

resource "google_project_service" "apis" {
  for_each = toset(local.required_apis)

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "random_id" "suffix" {
  byte_length = 2
}

# ---------------------------------------------------------------------------
# Encryption keys (customer-managed, auto-rotated)
# ---------------------------------------------------------------------------
module "encryption" {
  count  = var.enable_cmek ? 1 : 0
  source = "./modules/encryption"

  name           = local.name
  project_id     = var.project_id
  suffix         = random_id.suffix.hex
  primary_region = var.region
  backup_region  = var.backup_region
  rotation_days  = var.kms_rotation_days
  labels         = local.labels

  depends_on = [google_project_service.apis]
}

# ---------------------------------------------------------------------------
# Buckets: live data (primary region) and backups (second region)
# ---------------------------------------------------------------------------
module "data_bucket" {
  source = "./modules/bucket"

  name             = local.data_bucket_name
  project_id       = var.project_id
  location         = var.region
  storage_class    = "STANDARD"
  versioning       = true
  soft_delete_days = var.soft_delete_days
  enable_cmek      = var.enable_cmek
  kms_key_name     = var.enable_cmek ? module.encryption[0].primary_key_id : null
  force_destroy    = var.force_destroy
  lifecycle_rules  = local.data_lifecycle_rules
  labels           = merge(local.labels, { purpose = "live-data", data-class = "hot-to-archive" })

  depends_on = [google_project_service.apis, module.encryption]
}

module "backup_bucket" {
  source = "./modules/bucket"

  name             = local.backup_bucket_name
  project_id       = var.project_id
  location         = var.backup_region
  storage_class    = "NEARLINE"
  versioning       = true
  soft_delete_days = var.soft_delete_days
  enable_cmek      = var.enable_cmek
  kms_key_name     = var.enable_cmek ? module.encryption[0].backup_key_id : null
  force_destroy    = var.force_destroy
  lifecycle_rules  = local.backup_lifecycle_rules
  labels           = merge(local.labels, { purpose = "backup", data-class = "cold" })

  depends_on = [google_project_service.apis, module.encryption]
}

# Sample files create the logical folder hierarchy (documents/, images/, reports/, databases/, logs/).
resource "google_storage_bucket_object" "sample" {
  for_each = local.sample_files

  bucket = module.data_bucket.name
  name   = each.value
  source = "${path.module}/sample-data/${each.value}"
}

# ---------------------------------------------------------------------------
# Identity and access
# ---------------------------------------------------------------------------
module "iam" {
  source = "./modules/iam"

  name           = local.name
  project_id     = var.project_id
  data_bucket    = module.data_bucket.name
  backup_bucket  = module.backup_bucket.name
  reader_members = var.reader_members
  writer_members = var.writer_members
  admin_members  = var.admin_members

  depends_on = [google_project_service.apis]
}

# Who read, wrote or deleted what: Cloud Audit data-access logs for Cloud Storage.
resource "google_project_iam_audit_config" "storage" {
  count = var.enable_audit_logs ? 1 : 0

  project = var.project_id
  service = "storage.googleapis.com"

  audit_log_config {
    log_type = "ADMIN_READ"
  }

  audit_log_config {
    log_type = "DATA_READ"
  }

  audit_log_config {
    log_type = "DATA_WRITE"
  }

  depends_on = [google_project_service.apis]
}

# ---------------------------------------------------------------------------
# Automated backups
# ---------------------------------------------------------------------------
module "backup" {
  source = "./modules/backup"

  project_id         = var.project_id
  source_bucket      = module.data_bucket.name
  destination_bucket = module.backup_bucket.name
  interval_hours     = var.backup_interval_hours
  start_hour_utc     = var.backup_start_hour_utc

  depends_on = [google_project_service.apis]
}
