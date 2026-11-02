variable "name" {
  description = "Name prefix for keys and key rings."
  type        = string
}

variable "project_id" {
  description = "Project that owns the keys."
  type        = string
}

variable "suffix" {
  description = "Random suffix that keeps key ring names unique across deployments."
  type        = string
}

variable "primary_region" {
  description = "Region of the key for the primary data bucket."
  type        = string
}

variable "backup_region" {
  description = "Region of the key for the backup bucket."
  type        = string
}

variable "rotation_days" {
  description = "Automatic key rotation period in days."
  type        = number
}

variable "labels" {
  description = "Labels applied to the keys."
  type        = map(string)
  default     = {}
}
