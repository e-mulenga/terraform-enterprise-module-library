variable "bucket_name" {
  type = string
}

variable "purpose" {
  type    = string
  default = "general"
}

variable "versioning_enabled" {
  type    = bool
  default = true
}

variable "kms_key_arn" {
  type    = string
  default = ""
}

variable "access_log_bucket" {
  type    = string
  default = ""
}

variable "force_destroy" {
  type    = bool
  default = false
}

variable "lifecycle_rules" {
  type    = any
  default = []
}

variable "additional_bucket_policy_statements" {
  type    = any
  default = []
}
