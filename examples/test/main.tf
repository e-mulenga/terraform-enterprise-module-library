# ============================================================
# examples/test — Module Library Test Environment Example
# ============================================================
# Mirrors prod architecture with reduced sizing.
# Used for integration testing before prod promotion.
# ============================================================

module "vpc" {
  source = "../../modules/vpc"

  organization_name       = var.organization_name
  environment             = var.environment
  vpc_cidr                = var.vpc_cidr
  az_count                = 3              # Match prod AZ count
  single_nat_gateway      = true           # Cost saving — not prod
  flow_log_retention_days = 90
  kms_key_arn             = module.kms_vpc.key_arn
}

module "kms_vpc" {
  source            = "../../modules/kms"
  organization_name = var.organization_name
  environment       = var.environment
  purpose           = "vpc-flow-logs"
}

module "kms_rds" {
  source            = "../../modules/kms"
  organization_name = var.organization_name
  environment       = var.environment
  purpose           = "rds"
  service_principals = ["rds.amazonaws.com"]
}

module "app_bucket" {
  source = "../../modules/s3"

  bucket_name        = "${var.organization_name}-${var.environment}-app"
  kms_key_arn        = module.kms_vpc.key_arn
  versioning_enabled = true

  lifecycle_rules = [{
    id          = "cleanup-test-artifacts"
    expiration_days = 90
    transitions = [{ days = 30, storage_class = "STANDARD_IA" }]
  }]
}

module "cloudtrail" {
  source = "../../modules/cloudtrail"

  organization_name = var.organization_name
  environment       = var.environment
  s3_bucket_name    = var.cloudtrail_bucket
  kms_key_arn       = module.kms_vpc.key_arn
  log_retention_days = 180
  is_multi_region   = true
}

module "guardduty" {
  source = "../../modules/guardduty"

  organization_name = var.organization_name
  environment       = var.environment
  enabled           = true
}

module "security_hub" {
  source = "../../modules/security-hub"

  organization_name = var.organization_name
  environment       = var.environment
}

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
