# ============================================================
# Terraform Enterprise Module Library — Root Outputs
# ============================================================
# Outputs from the landing zone remote state, surfaced here
# for downstream consumers within the portfolio.
# ============================================================

# ---- Landing Zone Remote State (data source) ---------------
data "terraform_remote_state" "landing_zone" {
  count   = var.landing_zone_state_bucket != "" ? 1 : 0
  backend = "s3"

  config = {
    bucket = var.landing_zone_state_bucket
    key    = var.landing_zone_state_key
    region = var.aws_region
  }
}

locals {
  lz = length(data.terraform_remote_state.landing_zone) > 0 ? data.terraform_remote_state.landing_zone[0].outputs : {}
}

output "organisation_id" {
  description = "AWS Organisation ID (from landing zone state)."
  value       = try(local.lz.organization_id, null)
}

output "security_account_id" {
  description = "Security account ID (from landing zone state)."
  value       = try(local.lz.security_account_id, null)
}

output "logging_account_id" {
  description = "Logging account ID (from landing zone state)."
  value       = try(local.lz.logging_account_id, null)
}

output "cloudtrail_bucket_name" {
  description = "Centralised CloudTrail S3 bucket name."
  value       = try(local.lz.cloudtrail_bucket_name, null)
}

output "kms_cloudtrail_key_arn" {
  description = "KMS key ARN for CloudTrail encryption."
  value       = try(local.lz.kms_cloudtrail_key_arn, null)
  sensitive   = true
}

output "guardduty_detector_id" {
  description = "GuardDuty detector ID in the Security account."
  value       = try(local.lz.guardduty_detector_id, null)
}
