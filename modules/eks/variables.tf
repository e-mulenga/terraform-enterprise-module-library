variable "organization_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "cluster_name" {
  type    = string
  default = "cluster"
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "public_subnet_ids" {
  type    = list(string)
  default = []
}

variable "kms_key_arn" {
  type = string
}

variable "kubernetes_version" {
  type    = string
  default = "1.29"
}

variable "service_cidr" {
  type    = string
  default = "172.20.0.0/16"
}

variable "enable_public_endpoint" {
  type    = bool
  default = false
}

variable "public_access_cidrs" {
  type    = list(string)
  default = []
}

variable "log_retention_days" {
  type    = number
  default = 90
}

variable "node_groups" {
  type = map(object({
    instance_types = list(string)
    desired_size   = number
    min_size       = number
    max_size       = number
  }))

  default = {
    general = {
      instance_types = ["t3.medium"]
      desired_size   = 2
      min_size       = 1
      max_size       = 5
    }
  }
}
