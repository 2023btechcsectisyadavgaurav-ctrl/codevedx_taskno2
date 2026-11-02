# Offline tests: the providers are mocked, so no GCP account or credentials are needed.
# Run with:  terraform init -backend=false && terraform test

mock_provider "google" {}
mock_provider "random" {}
mock_provider "time" {}

variables {
  project_id = "test-project"
}

# --- Well-organized ---------------------------------------------------------
run "buckets_follow_a_logical_hierarchy" {
  command = plan

  assert {
    condition     = output.object_hierarchy == tolist(["databases", "documents", "images", "logs", "reports"])
    error_message = "Sample data should create the folders databases/, documents/, images/, logs/ and reports/."
  }

  assert {
    condition     = can(regex("^cloudstore-dev-data-", output.data_bucket_name)) && can(regex("^cloudstore-dev-backup-", output.backup_bucket_name))
    error_message = "Buckets should follow the <prefix>-<env>-<purpose>-<project> naming standard."
  }

  assert {
    condition     = output.design_summary.data_class == "STANDARD"
    error_message = "The live data bucket should use the Standard class."
  }
}

run "sample_data_can_be_skipped" {
  command = plan

  variables {
    upload_sample_data = false
  }

  assert {
    condition     = length(output.object_hierarchy) == 0
    error_message = "No folders should be created when upload_sample_data is false."
  }
}

# --- Secure -----------------------------------------------------------------
run "buckets_are_private_and_encrypted" {
  command = plan

  assert {
    condition     = alltrue([for v in output.design_summary.public_access : v == "enforced"])
    error_message = "Both buckets must enforce public access prevention."
  }

  assert {
    condition     = alltrue(output.design_summary.uniform_access)
    error_message = "Both buckets must use uniform bucket-level access (IAM only, no ACLs)."
  }

  assert {
    condition     = alltrue(output.design_summary.cmek)
    error_message = "Both buckets must be encrypted with customer-managed keys by default."
  }

  assert {
    condition     = output.design_summary.audit_logging
    error_message = "Audit data-access logging must be on by default."
  }
}

run "cmek_can_be_disabled" {
  command = plan

  variables {
    enable_cmek = false
  }

  assert {
    condition     = !anytrue(output.design_summary.cmek)
    error_message = "With enable_cmek = false no bucket should reference a KMS key."
  }

  assert {
    condition     = length(output.kms_keys) == 0
    error_message = "No KMS keys should be created when enable_cmek is false."
  }
}

# --- Reliable ---------------------------------------------------------------
run "backups_are_versioned_and_in_another_region" {
  command = plan

  assert {
    condition     = alltrue(output.design_summary.versioning)
    error_message = "Versioning must be enabled on both buckets."
  }

  assert {
    condition     = alltrue([for s in output.design_summary.soft_delete_seconds : s == 604800])
    error_message = "Soft delete should keep deleted objects for 7 days by default."
  }

  assert {
    condition     = lower(output.design_summary.data_location) != lower(output.design_summary.backup_location)
    error_message = "The backup bucket must be in a different region from the data bucket."
  }

  assert {
    condition     = output.design_summary.backup_interval_hours == 24
    error_message = "Backups should run daily by default."
  }
}

# --- Cost-effective ---------------------------------------------------------
run "lifecycle_cools_data_down_by_access_frequency" {
  command = plan

  assert {
    condition     = toset(output.design_summary.data_transitions) == toset(["NEARLINE", "COLDLINE", "ARCHIVE"])
    error_message = "Live data should move Standard -> Nearline -> Coldline -> Archive."
  }

  assert {
    condition     = output.design_summary.backup_class == "NEARLINE"
    error_message = "Backups are written once and rarely read, so they should start in Nearline."
  }

  assert {
    condition     = toset(output.design_summary.backup_transitions) == toset(["COLDLINE", "ARCHIVE"])
    error_message = "Backups should continue cooling to Coldline and Archive."
  }
}

# --- Input validation -------------------------------------------------------
run "rejects_backup_in_same_region" {
  command = plan

  variables {
    backup_region = "us-central1"
  }

  expect_failures = [var.backup_region]
}

run "rejects_public_principals" {
  command = plan

  variables {
    reader_members = ["allUsers"]
  }

  expect_failures = [var.reader_members]
}

run "rejects_coldline_before_nearline" {
  command = plan

  variables {
    coldline_after_days = 20
  }

  expect_failures = [var.coldline_after_days]
}

run "rejects_archive_before_coldline" {
  command = plan

  variables {
    archive_after_days = 60
  }

  expect_failures = [var.archive_after_days]
}

run "rejects_invalid_soft_delete" {
  command = plan

  variables {
    soft_delete_days = 3
  }

  expect_failures = [var.soft_delete_days]
}

run "rejects_bad_backup_interval" {
  command = plan

  variables {
    backup_interval_hours = 0
  }

  expect_failures = [var.backup_interval_hours]
}

run "rejects_bad_environment" {
  command = plan

  variables {
    environment = "qa"
  }

  expect_failures = [var.environment]
}
