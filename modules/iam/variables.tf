variable "role_name" {
  type = string
}

variable "description" {
  type    = string
  default = ""
}

variable "path" {
  type    = string
  default = "/"
}

variable "purpose" {
  type    = string
  default = "general"
}

variable "assume_role_policy" {
  type = string
}

variable "managed_policy_arns" {
  type    = list(string)
  default = []
}

variable "inline_policy" {
  type    = string
  default = ""
}

variable "permissions_boundary_arn" {
  type    = string
  default = null
}

variable "max_session_duration" {
  type    = number
  default = 3600
}

variable "create_instance_profile" {
  type    = bool
  default = false
}

variable "organization_name" { 
  type = string 
}

variable "environment" { 
  type = string 
}

variable "account_id" { 
  type = string 
}

variable "partition" {
  type    = string
  default = "aws"
}

variable "region" { 
  type = string 
}

variable "artifact_bucket_name" { 
  type = string 
}

variable "kms_key_arn" { 
  type = string 
}

variable "dev_account_id" { 
  type = string 
}

variable "test_account_id" { 
  type = string 
}

variable "prod_account_id" { 
  type = string 
}

variable "codeartifact_domain_name" {
  type    = string
  default = ""
}

variable "codeartifact_enabled" {
  type    = bool
  default = true
}
