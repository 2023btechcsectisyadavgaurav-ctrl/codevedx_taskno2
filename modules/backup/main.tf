# Automated backups: Storage Transfer Service copies new and changed objects from the data bucket
# to the backup bucket (in another region) on a schedule. Nothing is ever deleted from the backup.

data "google_storage_transfer_project_service_account" "sts" {
  project = var.project_id
}

locals {
  sts_member = "serviceAccount:${data.google_storage_transfer_project_service_account.sts.email}"

  # Schedule starts today; ignore_changes below stops this moving target from causing diffs.
  now = timestamp()
}

# The transfer service reads the source and writes to the destination with its own Google-managed identity.
resource "google_storage_bucket_iam_member" "source_viewer" {
  bucket = var.source_bucket
  role   = "roles/storage.objectViewer"
  member = local.sts_member
}

resource "google_storage_bucket_iam_member" "source_bucket_reader" {
  bucket = var.source_bucket
  role   = "roles/storage.legacyBucketReader"
  member = local.sts_member
}

resource "google_storage_bucket_iam_member" "sink_object_admin" {
  bucket = var.destination_bucket
  role   = "roles/storage.objectAdmin"
  member = local.sts_member
}

resource "google_storage_bucket_iam_member" "sink_bucket_writer" {
  bucket = var.destination_bucket
  role   = "roles/storage.legacyBucketWriter"
  member = local.sts_member
}

# The job validates access when it is created, so wait for IAM to propagate first.
resource "time_sleep" "iam_propagation" {
  create_duration = "45s"

  depends_on = [
    google_storage_bucket_iam_member.source_viewer,
    google_storage_bucket_iam_member.source_bucket_reader,
    google_storage_bucket_iam_member.sink_object_admin,
    google_storage_bucket_iam_member.sink_bucket_writer,
  ]
}

resource "google_storage_transfer_job" "backup" {
  project     = var.project_id
  description = "Backup ${var.source_bucket} to ${var.destination_bucket} every ${var.interval_hours}h"

  transfer_spec {
    gcs_data_source {
      bucket_name = var.source_bucket
    }

    gcs_data_sink {
      bucket_name = var.destination_bucket
    }

    transfer_options {
      overwrite_when                            = "DIFFERENT"
      delete_objects_from_source_after_transfer = false
      delete_objects_unique_in_sink             = false
    }
  }

  schedule {
    schedule_start_date {
      year  = tonumber(formatdate("YYYY", local.now))
      month = tonumber(formatdate("M", local.now))
      day   = tonumber(formatdate("D", local.now))
    }

    start_time_of_day {
      hours   = var.start_hour_utc
      minutes = 0
      seconds = 0
      nanos   = 0
    }

    repeat_interval = "${var.interval_hours * 3600}s"
  }

  lifecycle {
    ignore_changes = [schedule]
  }

  depends_on = [time_sleep.iam_propagation]
}
