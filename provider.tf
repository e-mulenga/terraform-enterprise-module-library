# ============================================================
# Terraform Enterprise Module Library — Provider Configuration
# ============================================================
# Portfolio Standard: provider.tf contains BOTH the terraform{}
# block AND provider configurations. No versions.tf is used.
#
# This root provider.tf configures the default AWS provider
# used when running the examples/ directly. Each module defines
# no provider itself — consumers pass providers via composition.
# ============================================================

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
  }

  # Remote backend overridden per environment in examples/<env>/backend.tf
  backend "s3" {}
}

# ---- Default provider (management / single-account examples) -
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy   = "Terraform"
      Repository  = "terraform-enterprise-module-library"
      Portfolio   = "enterprise-cloud-platform"
      Owner       = var.owner
      CostCenter  = var.cost_center
      Environment = var.environment
    }
  }
}
