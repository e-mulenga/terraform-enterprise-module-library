# ============================================================
# Terraform Enterprise Module Library — Root Variables
# ============================================================
# These variables apply when running examples/ directly.
# Individual modules declare their own variables independently.
# ============================================================

variable "aws_region" {
  type        = string
  description = "AWS region to deploy example resources."
  default     = "af-south-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "aws_region must be a valid AWS region identifier (e.g. af-south-1)."
  }
}

variable "environment" {
  type        = string
  description = "Deployment environment: dev | test | prod."

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be one of: dev, test, prod."
  }
}

variable "organization_name" {
  type        = string
  description = "Short organisation name used in all resource naming (3-30 lowercase chars)."

  validation {
    condition     = can(regex("^[a-z0-9-]{3,30}$", var.organization_name))
    error_message = "organization_name must be 3-30 lowercase alphanumeric characters or hyphens."
  }
}

variable "owner" {
  type        = string
  description = "Team or person responsible — applied as a tag on all resources."
}

variable "cost_center" {
  type        = string
  description = "Cost center code for billing allocation."
}

variable "landing_zone_state_bucket" {
  type        = string
  description = "S3 bucket containing the aws-enterprise-landing-zone Terraform state."
  default     = ""
}

variable "landing_zone_state_key" {
  type        = string
  description = "State key path in the landing zone S3 bucket."
  default     = "landing-zone/prod/terraform.tfstate"
}

variable "tags" {
  type        = map(string)
  description = "Additional tags merged with the provider default_tags."
  default     = {}
}
