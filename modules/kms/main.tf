# ============================================================
# Module: kms — Reusable Customer-Managed KMS Key
# ============================================================
# WAF Pillars: Security, Cost Optimization
#
# Creates a single CMK with configurable key policy,
# automatic rotation, alias, and optional multi-region support.
# ============================================================

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  partition   = data.aws_partition.current.partition
  name_prefix = "${var.organization_name}-${var.environment}"

  service_statements = [
    for svc in var.service_principals : {
      Sid       = "AllowService-${replace(svc, ".", "-")}"
      Effect    = "Allow"
      Principal = { Service = svc }
      Action    = ["kms:GenerateDataKey*", "kms:Decrypt", "kms:DescribeKey"]
      Resource  = "*"
    }
  ]

  cross_account_statements = length(var.cross_account_principals) > 0 ? [{
    Sid       = "AllowCrossAccountAccess"
    Effect    = "Allow"
    Principal = { AWS = var.cross_account_principals }
    Action    = ["kms:Decrypt", "kms:DescribeKey", "kms:GenerateDataKey"]
    Resource  = "*"
  }] : []
}

resource "aws_kms_key" "main" {
  description             = coalesce(var.description, "CMK for ${var.purpose} — ${local.name_prefix}")
  deletion_window_in_days = var.deletion_window_days
  enable_key_rotation     = var.enable_rotation
  multi_region            = var.multi_region
  is_enabled              = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [{
        Sid       = "EnableRootAccountAccess"
        Effect    = "Allow"
        Principal = { AWS = "arn:${local.partition}:iam::${local.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      }],
      local.service_statements,
      local.cross_account_statements,
      var.additional_policy_statements
    )
  })

  tags = {
    Name    = "${local.name_prefix}-${var.purpose}-key"
    Purpose = var.purpose
  }
}

resource "aws_kms_alias" "main" {
  name          = "alias/${local.name_prefix}-${var.purpose}"
  target_key_id = aws_kms_key.main.key_id
}
