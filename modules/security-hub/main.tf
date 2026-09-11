# ============================================================
# Module: security-hub — Security Hub with CIS + FSBP + NIST
# ============================================================
resource "aws_securityhub_account" "main" {
  enable_default_standards  = false
  control_finding_generator = "SECURITY_CONTROL"
  auto_enable_controls      = true
}

data "aws_region" "current" {}

resource "aws_securityhub_standards_subscription" "cis" {
  standards_arn = "arn:aws:securityhub:::ruleset/cis-aws-foundations-benchmark/v/1.4.0"
  depends_on    = [aws_securityhub_account.main]
}

resource "aws_securityhub_standards_subscription" "fsbp" {
  standards_arn = "arn:aws:securityhub:${data.aws_region.current.name}::standards/aws-foundational-security-best-practices/v/1.0.0"
  depends_on    = [aws_securityhub_account.main]
}

resource "aws_securityhub_standards_subscription" "nist" {
  standards_arn = "arn:aws:securityhub:${data.aws_region.current.name}::standards/nist-800-53/v/5.0.0"
  depends_on    = [aws_securityhub_account.main]
}

resource "aws_sns_topic" "alerts" {
  name              = "${var.organization_name}-${var.environment}-sechub-alerts"
  kms_master_key_id = "alias/aws/sns"
  tags              = { Name = "${var.organization_name}-${var.environment}-sechub-alerts" }
}

resource "aws_cloudwatch_event_rule" "critical" {
  name        = "${var.organization_name}-${var.environment}-sechub-critical"
  description = "Security Hub CRITICAL/HIGH findings"
  event_pattern = jsonencode({
    source      = ["aws.securityhub"]
    detail-type = ["Security Hub Findings - Imported"]
    detail = {
      findings = {
        Severity    = { Label = ["CRITICAL","HIGH"] }
        Workflow    = { Status = ["NEW"] }
        RecordState = ["ACTIVE"]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "sechub_sns" {
  rule      = aws_cloudwatch_event_rule.critical.name
  target_id = "SNS"
  arn       = aws_sns_topic.alerts.arn
}
