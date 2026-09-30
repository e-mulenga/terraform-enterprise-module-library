variable "organization_name" { 
  type = string 
}

variable "environment"        { 
  type = string
  default = "test" 
}

variable "vpc_cidr"           { 
  type = string
  default = "10.20.0.0/16" 
}

variable "cloudtrail_bucket"  { 
  type = string 
}