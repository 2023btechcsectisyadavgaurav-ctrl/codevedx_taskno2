# Backup & Recovery Runbook

How data is protected, and exactly how to get it back. Replace `DATA`, `BACKUP`, `JOB` and `PROJECT` with the values from `terraform output`.

```bash
terraform output data_bucket_url      # gs://cloudstore-dev-data-<project>
terraform output backup_bucket_url    # gs://cloudstore-dev-backup-<project>
terraform output backup_job_name      # transferJobs/<id>
```

## 1. Backup schedule

| Layer | What it protects against | Schedule / setting | Recovery point (RPO) |
|---|---|---|---|
| **Object versioning** (data bucket) | Accidental overwrite or delete | Continuous; keeps up to 5 old versions, each for 30 days | Seconds (every change) |
| **Soft delete** (both buckets) | Deleted objects and old versions | Deleted data recoverable for 7 days | Seconds |
| **Automated backup job** (Storage Transfer Service) | Bucket deleted, regional outage, ransomware or corruption of the live bucket | Every 24 h at 02:00 UTC (`backup_interval_hours`, `backup_start_hour_utc`) | Up to 24 h |
| **Second region** | Loss of the whole primary region | Backup bucket is in `us-east1`, data bucket in `us-central1` | Up to 24 h |
| **Backup versioning** | A bad file synced into the backup | Backup bucket is versioned; old versions kept 30 days | Per backup run |

**Recovery time objective (RTO):** minutes for a single object or folder, under an hour for a full bucket restore (depends on data size).

The backup job copies new and changed objects. It never deletes anything from the backup bucket (`delete_objects_unique_in_sink = false`), so deleting a file from the live bucket does not delete it from the backup.

## 2. Recovery procedures

### A. Restore one object that was overwritten or deleted (versioning)

1. List all versions, including deleted ones. Each line ends with `#<generation>`:
   ```bash
   gcloud storage ls -a DATA/documents/company-policy.txt
   ```
2. Copy the wanted generation back as the live object:
   ```bash
   gcloud storage cp "DATA/documents/company-policy.txt#1699999999999999" DATA/documents/company-policy.txt
   ```
3. Verify:
   ```bash
   gcloud storage cat DATA/documents/company-policy.txt
   ```

### B. Restore a deleted object using soft delete

1. List soft-deleted objects:
   ```bash
   gcloud storage ls --soft-deleted DATA/documents/
   ```
2. Restore it (use the generation shown):
   ```bash
   gcloud storage restore "DATA/documents/company-policy.txt#1699999999999999"
   ```

### C. Restore a folder or the whole bucket from the backup bucket (disaster recovery)

Use this when the live bucket is damaged, deleted or its region is down.

1. If the data bucket was deleted, re-create it (`terraform apply`), or restore into any new bucket.
2. Copy everything back:
   ```bash
   gcloud storage rsync -r BACKUP DATA
   ```
   Restore a single folder only:
   ```bash
   gcloud storage rsync -r BACKUP/documents DATA/documents
   ```
3. Spot-check the result:
   ```bash
   gcloud storage ls -r DATA
   ```

The service account `cloudstore-<env>-restore` has exactly the permissions needed (read backups, write the data bucket). Run the restore as that identity in production:

```bash
gcloud storage rsync -r BACKUP DATA --impersonate-service-account=cloudstore-dev-restore@PROJECT.iam.gserviceaccount.com
```

### D. Run a backup immediately (before a risky change)

```bash
gcloud transfer jobs run JOB
```

Check progress in the console: **Data Transfer → Transfer jobs**.

### E. Backup job failed or is overdue

1. Console → **Data Transfer → Transfer jobs → JOB → Run history**: read the error.
2. Most common cause: the transfer service lost bucket permissions. `terraform apply` re-creates them.
3. As a stop-gap run `gcloud storage rsync -r DATA BACKUP`.

## 3. Quarterly recovery test (do not skip)

A backup is only proven when it has been restored.

1. Pick three random objects from `BACKUP`.
2. Restore them into a scratch bucket with procedure C.
3. Compare checksums with the originals (`gcloud storage hash`).
4. Record date, result and who ran it in the team's change log.

## 4. Encryption keys during recovery

Both buckets are encrypted with customer-managed keys in Cloud KMS (rotated every 90 days). Rotation keeps old key versions, so old data stays readable. **Never destroy a key version that still protects data**: the data becomes permanently unreadable. Key rings cannot be deleted in GCP, and Terraform names them with a random suffix so re-deployments do not collide.
