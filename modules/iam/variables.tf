variable "name" {
  description = "Name prefix for the service accounts (keep it short: account IDs are limited to 30 characters)."
  type        = string
}

variable "project_id" {
  description = "Project that owns the service accounts."
  type        = string
}

variable "data_bucket" {
  description = "Name of the primary data bucket."
  type        = string
}

variable "backup_bucket" {
  description = "Name of the backup bucket."
  type        = string
}

variable "reader_members" {
  description = "Extra members with read-only access to the data bucket."
  type        = list(string)
  default     = []
}

variable "writer_members" {
  description = "Extra members with read/write access to the data bucket."
  type        = list(string)
  default     = []
}

variable "admin_members" {
  description = "Extra members with full control of both buckets."
  type        = list(string)
  default     = []
}
