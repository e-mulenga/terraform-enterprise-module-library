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
