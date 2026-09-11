variable "organization_name" { type = string }
variable "environment"        { type = string }
variable "s3_bucket_name"    { type = string }
variable "kms_key_arn"       { type = string }
variable "log_retention_days" {
  type    = number
  default = 365
}
variable "is_multi_region" {
  type    = bool
  default = true
}
