variable "organization_name"      { 
  type = string 
}

variable "environment"             { 
  type = string 
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "az_count" {
  type    = number
  default = 3
}

variable "single_nat_gateway" {
  type        = bool
  default     = false
  description = "Use one NAT GW (cost saving for dev). Prod should be false."
}

variable "flow_log_retention_days" {
  type    = number
  default = 90
}

variable "kms_key_arn" {
  type    = string
  default = ""
}
