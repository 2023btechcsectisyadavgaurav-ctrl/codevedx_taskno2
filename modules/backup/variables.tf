variable "project_id" {
  description = "Project that owns the transfer job."
  type        = string
}

variable "source_bucket" {
  description = "Bucket to back up (the live data bucket)."
  type        = string
}

variable "destination_bucket" {
  description = "Bucket that receives the backups (in another region)."
  type        = string
}

variable "interval_hours" {
  description = "Hours between backup runs."
  type        = number
}

variable "start_hour_utc" {
  description = "Hour of day (UTC) the schedule starts."
  type        = number
}
