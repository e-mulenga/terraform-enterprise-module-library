variable "organization_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "purpose" {
  type        = string
  description = "Short label used in the key alias and name tag (e.g. rds, s3, eks)."
}

variable "description" {
  type    = string
  default = ""
}

variable "deletion_window_days" {
  type    = number
  default = 30
}

variable "enable_rotation" {
  type    = bool
  default = true
}

variable "multi_region" {
  type    = bool
  default = false
}

variable "replica_region" {
  type    = string
  default = ""
}

variable "service_principals" {
  type    = list(string)
  default = []
}

variable "cross_account_principals" {
  type    = list(string)
  default = []
}

variable "additional_policy_statements" {
  type    = any
  default = []
}
