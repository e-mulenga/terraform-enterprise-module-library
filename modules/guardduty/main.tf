# ============================================================
# Module: guardduty — GuardDuty Detector (Workload Account)
# ============================================================
resource "aws_guardduty_detector" "main" {
  enable = var.enabled
  tags   = { Name = "${var.organization_name}-${var.environment}-guardduty" }
}

resource "aws_sns_topic" "findings" {
  name              = "${var.organization_name}-${var.environment}-guardduty-findings"
  kms_master_key_id = "alias/aws/sns"
  tags              = { Name = "${var.organization_name}-${var.environment}-guardduty-findings" }
}

resource "aws_cloudwatch_event_rule" "high_severity" {
  name        = "${var.organization_name}-${var.environment}-gd-high"
  description = "GuardDuty findings severity >= 7"
  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail      = { severity = [{ numeric = [">=", 7] }] }
  })
}

resource "aws_cloudwatch_event_target" "sns" {
  rule      = aws_cloudwatch_event_rule.high_severity.name
  target_id = "SNS"
  arn       = aws_sns_topic.findings.arn
}
