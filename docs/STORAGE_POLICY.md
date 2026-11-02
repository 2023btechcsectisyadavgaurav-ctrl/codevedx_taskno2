# Storage Policy

The rules this platform enforces. Every rule below is implemented in Terraform, so the policy cannot silently drift.

## 1. Organization and naming

| Item | Standard |
|---|---|
| Bucket name | `<prefix>-<environment>-<purpose>-<project-id>`, e.g. `cloudstore-dev-data-my-project` |
| Purposes | `data` (live), `backup` (disaster recovery copy) |
| Folders | Top-level prefixes by data type: `documents/`, `images/`, `reports/`, `databases/`, `logs/` |
| Labels | `project`, `environment`, `managed-by`, `purpose`, `data-class` on every bucket and key |
| Locations | Data in the primary region, backup in a **different** region |

## 2. Security

| Control | Rule |
|---|---|
| Public access | **Never.** Public access prevention is enforced on every bucket, and the Terraform variables reject `allUsers` / `allAuthenticatedUsers`. |
| Access model | Uniform bucket-level access: IAM only, no per-object ACLs. |
| Least privilege | Separate service accounts: `writer` (read/write data), `reader` (read data), `restore` (read backups, write data). Humans get only `reader_members`, `writer_members` or `admin_members`. |
| Backup protection | Nobody can write to the backup bucket except admins and the backup job. |
| Encryption at rest | Customer-managed keys (Cloud KMS), one per region, automatically rotated every 90 days. |
| Encryption in transit | Cloud Storage serves only over TLS. |
| Audit | Cloud Audit data-access logs record every read, write and delete. |

## 3. Reliability

| Control | Rule |
|---|---|
| Versioning | On for both buckets. Up to 5 old versions per object, each kept 30 days. |
| Soft delete | Deleted data stays recoverable for 7 days. |
| Backup | Automatic copy to the second region every 24 h. Backups are never deleted by the job. |
| Recovery tests | Quarterly (see `RECOVERY_RUNBOOK.md`). |

## 4. Cost: storage classes by access frequency

| Class | Used for | When objects get there | Typical access |
|---|---|---|---|
| **Standard** | Active, frequently accessed data | New objects in the data bucket | Daily |
| **Nearline** | Infrequent access | After 30 days (data bucket); backups start here | About monthly |
| **Coldline** | Rare access | After 90 days | About quarterly |
| **Archive** | Long-term retention | After 365 days | Yearly or less |

Lifecycle rules move objects automatically; nobody has to remember. Cooler classes cost far less to store but more to read and have minimum storage durations (Nearline 30 days, Coldline 90, Archive 365), which is why the transition ages above respect them. Old object versions are deleted after 30 days and never exceed 5 per object, so versioning cannot grow without limit.

To tune the thresholds change `nearline_after_days`, `coldline_after_days` and `archive_after_days`.

## 5. Change control

All changes go through Terraform (`terraform plan`, review, `terraform apply`). Manual console edits are drift and will be reverted by the next apply.
