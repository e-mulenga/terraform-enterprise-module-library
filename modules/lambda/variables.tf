variable "organization_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "function_name" {
  type = string
}

variable "description" {
  type    = string
  default = ""
}

variable "runtime" {
  type    = string
  default = "python3.12"
}

variable "handler" {
  type    = string
  default = "handler.lambda_handler"
}

variable "timeout" {
  type    = number
  default = 30
}

variable "memory_size" {
  type    = number
  default = 256
}

variable "architectures" {
  type    = list(string)
  default = ["arm64"]
}

variable "filename" {
  type    = string
  default = ""
}

variable "image_uri" {
  type    = string
  default = ""
}

variable "kms_key_arn" {
  type    = string
  default = ""
}

variable "environment_variables" {
  type    = map(string)
  default = {}
}

variable "reserved_concurrency" {
  type    = number
  default = -1
}

variable "log_retention_days" {
  type    = number
  default = 30
}

variable "vpc_id" {
  type    = string
  default = ""
}

variable "subnet_ids" {
  type    = list(string)
  default = []
}

variable "custom_policy" {
  type    = string
  default = ""
}
