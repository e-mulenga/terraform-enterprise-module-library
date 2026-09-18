variable "organization_name"         { 
  type = string 
}

variable "environment"               { 
  type = string 
}

variable "name" {
  type    = string
  default = "api"
}

variable "vpc_id"                    { 
  type = string 
}

variable "public_subnet_ids"         { 
  type = list(string) 
}

variable "private_subnet_ids"        { 
  type = list(string) 
}

variable "target_security_group_ids" { 
  type = list(string) 
}

variable "internal" {
  type    = bool
  default = false
}

variable "certificate_arn"           { 
  type = string 
}

variable "target_port" {
  type    = number
  default = 8080
}

variable "target_type" {
  type    = string
  default = "ip"
}

variable "health_check_path" {
  type    = string
  default = "/health"
}

variable "ingress_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "access_log_bucket"         { 
  type = string 
}
