variable "organization_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "name" {
  type        = string
  description = "Short name for this DB (e.g. api, auth, analytics)."
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "allowed_security_group_ids" {
  type    = list(string)
  default = []
}

variable "kms_key_arn" {
  type = string
}

variable "engine" {
  type    = string
  default = "postgres"
}

variable "engine_version" {
  type    = string
  default = "15.5"
}

variable "instance_class" {
  type    = string
  default = "db.t3.medium"
}

variable "parameter_group_family" {
  type    = string
  default = "postgres15"
}

variable "parameters" {
  type    = any
  default = []
}

variable "db_name" {
  type    = string
  default = "appdb"
}

variable "master_username" {
  type    = string
  default = "dbadmin"
}

variable "master_password" {
  type      = string
  sensitive = true
}

variable "port" {
  type    = number
  default = 5432
}

variable "allocated_storage" {
  type    = number
  default = 100
}

variable "max_allocated_storage" {
  type    = number
  default = 500
}

variable "multi_az" {
  type    = bool
  default = true
}

variable "backup_retention_days" {
  type    = number
  default = 35
}

variable "cloudwatch_log_exports" {
  type    = list(string)
  default = ["postgresql", "upgrade"]
}

variable "alarm_sns_topic_arns" {
  type    = list(string)
  default = []
}
