# Customer-managed encryption keys (Cloud KMS): one key per bucket region.
# Cloud KMS key rings cannot be deleted, so the names carry a random suffix; re-deploying later never collides.

data "google_storage_project_service_account" "gcs" {
  project = var.project_id
}

locals {
  gcs_agent = "serviceAccount:${data.google_storage_project_service_account.gcs.email_address}"
  rotation  = "${var.rotation_days * 86400}s"
}

resource "google_kms_key_ring" "primary" {
  name     = "${var.name}-${var.suffix}-primary"
  project  = var.project_id
  location = var.primary_region
}

resource "google_kms_crypto_key" "primary" {
  name            = "${var.name}-data-key"
  key_ring        = google_kms_key_ring.primary.id
  purpose         = "ENCRYPT_DECRYPT"
  rotation_period = local.rotation
  labels          = var.labels
}

resource "google_kms_key_ring" "backup" {
  name     = "${var.name}-${var.suffix}-backup"
  project  = var.project_id
  location = var.backup_region
}

resource "google_kms_crypto_key" "backup" {
  name            = "${var.name}-backup-key"
  key_ring        = google_kms_key_ring.backup.id
  purpose         = "ENCRYPT_DECRYPT"
  rotation_period = local.rotation
  labels          = var.labels
}

# Cloud Storage itself (its service agent) must be allowed to use the keys.
resource "google_kms_crypto_key_iam_member" "gcs_primary" {
  crypto_key_id = google_kms_crypto_key.primary.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = local.gcs_agent
}

resource "google_kms_crypto_key_iam_member" "gcs_backup" {
  crypto_key_id = google_kms_crypto_key.backup.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = local.gcs_agent
}

# IAM changes take a moment to propagate; wait so bucket creation does not race them.
resource "time_sleep" "iam_propagation" {
  create_duration = "45s"

  depends_on = [
    google_kms_crypto_key_iam_member.gcs_primary,
    google_kms_crypto_key_iam_member.gcs_backup,
  ]
}
