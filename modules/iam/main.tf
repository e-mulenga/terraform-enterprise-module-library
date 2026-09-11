# ============================================================
# Module: iam — Reusable IAM Role Factory
# ============================================================
# Creates a single IAM role with:
#   - Configurable trust policy (service, account, or OIDC)
#   - Managed policy attachments
#   - Optional inline policy
#   - Permission boundary support
# ============================================================

resource "aws_iam_role" "main" {
  name                 = var.role_name
  description          = var.description
  path                 = var.path
  max_session_duration = var.max_session_duration
  permissions_boundary = var.permissions_boundary_arn

  assume_role_policy = var.assume_role_policy

  tags = { Name = var.role_name, Purpose = var.purpose }
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each = toset(var.managed_policy_arns)

  role       = aws_iam_role.main.name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "inline" {
  count  = var.inline_policy != "" ? 1 : 0
  name   = "${var.role_name}-inline"
  role   = aws_iam_role.main.id
  policy = var.inline_policy
}

# ---- Instance Profile (for EC2 roles) -----------------------
resource "aws_iam_instance_profile" "main" {
  count = var.create_instance_profile ? 1 : 0
  name  = var.role_name
  role  = aws_iam_role.main.name
  tags  = { Name = "${var.role_name}-instance-profile" }
}
