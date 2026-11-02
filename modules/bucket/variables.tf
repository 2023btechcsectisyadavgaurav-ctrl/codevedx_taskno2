variable "name" {
  description = "Globally unique bucket name."
  type        = string
}

variable "project_id" {
  description = "Project that owns the bucket."
  type        = string
}

variable "location" {
  description = "Bucket location (region)."
  type        = string
}

variable "storage_class" {
  description = "Default storage class for new objects."
  type        = string
  default     = "STANDARD"

  validation {
    condition     = contains(["STANDARD", "NEARLINE", "COLDLINE", "ARCHIVE"], var.storage_class)
    error_message = "storage_class must be STANDARD, NEARLINE, COLDLINE or ARCHIVE."
  }
}

variable "versioning" {
  description = "Keep previous versions of overwritten and deleted objects."
  type        = bool
  default     = true
}

variable "soft_delete_days" {
  description = "Soft delete retention in days (0 disables it, otherwise 7-90)."
  type        = number
  default     = 7
}

variable "enable_cmek" {
  description = "Use a customer-managed encryption key."
  type        = bool
  default     = true
}

variable "kms_key_name" {
  description = "Full resource ID of the Cloud KMS key (used only when enable_cmek is true)."
  type        = string
  default     = null
}

variable "force_destroy" {
  description = "Delete the bucket even when it contains objects."
  type        = bool
  default     = true
}

variable "labels" {
  description = "Labels applied to the bucket."
  type        = map(string)
  default     = {}
}

variable "lifecycle_rules" {
  description = "Lifecycle rules (storage class transitions and deletions)."
  type = list(object({
    action = object({
      type          = string
      storage_class = optional(string)
    })
    condition = object({
      age                        = optional(number)
      matches_storage_class      = optional(list(string))
      days_since_noncurrent_time = optional(number)
      num_newer_versions         = optional(number)
    })
  }))
  default = []
}
