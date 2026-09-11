# ============================================================
# examples/dev — Module Library Development Example
# ============================================================
# Demonstrates all modules composed together in a dev environment.
# ============================================================

module "vpc" {
  source = "../../modules/vpc"

  organization_name    = var.organization_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  az_count             = 2              # 2 AZs sufficient for dev
  single_nat_gateway   = true           # Save NAT cost in dev
  flow_log_retention_days = 30
  kms_key_arn          = var.kms_key_arn
}

module "app_bucket" {
  source = "../../modules/s3"

  bucket_name         = "${var.organization_name}-${var.environment}-app-artifacts"
  purpose             = "app-artifacts"
  kms_key_arn         = var.kms_key_arn
  versioning_enabled  = true

  lifecycle_rules = [{
    id             = "expire-old-artifacts"
    expiration_days = 90
    transitions    = [{ days = 30, storage_class = "STANDARD_IA" }]
  }]
}

module "app_role" {
  source = "../../modules/iam"

  role_name   = "${var.organization_name}-${var.environment}-app-role"
  description = "Application runtime role for dev workloads."
  purpose     = "application"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]

  create_instance_profile = true
}

variable "organization_name" {
  type = string
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "vpc_cidr" {
  type    = string
  default = "10.10.0.0/16"
}

variable "kms_key_arn" {
  type    = string
  default = ""
}
