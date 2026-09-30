# ============================================================
# Variables
# ============================================================
variable "organization_name"    { 
  type = string 
}

variable "environment"          { 
  type = string
  default = "prod" 
}

variable "vpc_cidr"             { 
  type = string
  default = "10.30.0.0/16" 
}

variable "cloudtrail_bucket"    { 
  type = string 
}

variable "acm_certificate_arn"  { 
  type = string 
}

variable "db_master_password"   { 
  type = string
  sensitive = true 
}
