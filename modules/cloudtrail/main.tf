# ============================================================
# Module: cloudtrail — Account-level CloudTrail Trail
# ============================================================
# For organisation-wide trail, use the landing-zone module.
# This module provisions a per-account trail for workload
# accounts in the portfolio, delivering to the centralised
# log bucket provisioned by the landing zone.
# ============================================================

resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/${var.organization_name}-${var.environment}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
  tags              = { Name = "${var.organization_name}-${var.environment}-cloudtrail-lg" }
}

resource "aws_iam_role" "cloudtrail" {
  name = "${var.organization_name}-${var.environment}-cloudtrail-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "cloudtrail.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "cloudtrail" {
  role = aws_iam_role.cloudtrail.id
  name = "cloudwatch-delivery"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents","logs:DescribeLogGroups","logs:DescribeLogStreams"]
      Resource = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
    }]
  })
}

resource "aws_cloudtrail" "main" {
  name                          = "${var.organization_name}-${var.environment}-trail"
  s3_bucket_name                = var.s3_bucket_name
  kms_key_id                    = var.kms_key_arn
  include_global_service_events = true
  is_multi_region_trail         = var.is_multi_region
  is_organization_trail         = false
  enable_log_file_validation    = true
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.cloudtrail.arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true
    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::"]
    }
  }

  insight_selector { insight_type = "ApiCallRateInsight" }
  insight_selector { insight_type = "ApiErrorRateInsight" }

  tags = { Name = "${var.organization_name}-${var.environment}-trail" }
}
