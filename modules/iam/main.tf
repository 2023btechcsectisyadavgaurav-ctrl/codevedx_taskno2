# Least-privilege identities for the storage platform. No public principal is ever granted access.

resource "google_service_account" "writer" {
  project      = var.project_id
  account_id   = "${var.name}-writer"
  display_name = "Application writer (${var.name}): read and write the data bucket"
}

resource "google_service_account" "reader" {
  project      = var.project_id
  account_id   = "${var.name}-reader"
  display_name = "Read-only consumer (${var.name}): read the data bucket"
}

resource "google_service_account" "restore" {
  project      = var.project_id
  account_id   = "${var.name}-restore"
  display_name = "Restore operator (${var.name}): read backups, write the data bucket"
}

# --- Data bucket -----------------------------------------------------------
resource "google_storage_bucket_iam_member" "writer_data" {
  bucket = var.data_bucket
  role   = "roles/storage.objectUser"
  member = "serviceAccount:${google_service_account.writer.email}"
}

resource "google_storage_bucket_iam_member" "reader_data" {
  bucket = var.data_bucket
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.reader.email}"
}

resource "google_storage_bucket_iam_member" "restore_data" {
  bucket = var.data_bucket
  role   = "roles/storage.objectUser"
  member = "serviceAccount:${google_service_account.restore.email}"
}

# --- Backup bucket: only the restore operator may read it, nobody but admins may write ---
resource "google_storage_bucket_iam_member" "restore_backup" {
  bucket = var.backup_bucket
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.restore.email}"
}

# --- People and groups passed in by the caller -----------------------------
resource "google_storage_bucket_iam_member" "readers" {
  for_each = toset(var.reader_members)

  bucket = var.data_bucket
  role   = "roles/storage.objectViewer"
  member = each.value
}

resource "google_storage_bucket_iam_member" "writers" {
  for_each = toset(var.writer_members)

  bucket = var.data_bucket
  role   = "roles/storage.objectUser"
  member = each.value
}

resource "google_storage_bucket_iam_member" "admins_data" {
  for_each = toset(var.admin_members)

  bucket = var.data_bucket
  role   = "roles/storage.admin"
  member = each.value
}

resource "google_storage_bucket_iam_member" "admins_backup" {
  for_each = toset(var.admin_members)

  bucket = var.backup_bucket
  role   = "roles/storage.admin"
  member = each.value
}
