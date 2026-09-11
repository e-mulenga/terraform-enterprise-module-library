# ============================================================
# Module: lambda — Secure Serverless Function
# ============================================================
# WAF Pillars: Security, Cost Optimization, Performance Efficiency
#
# Creates a Lambda function with:
#   - VPC deployment (private subnets)
#   - KMS encryption for environment variables
#   - AWS X-Ray tracing
#   - Reserved concurrency (blast-radius control)
#   - Dead-letter queue (SQS)
#   - CloudWatch Logs with KMS encryption
#   - Least-privilege execution role
# ============================================================

locals {
  name_prefix     = "${var.organization_name}-${var.environment}-${var.function_name}"
  has_vpc_config  = length(var.subnet_ids) > 0
}

# ---- CloudWatch Log Group -----------------------------------
resource "aws_cloudwatch_log_group" "function" {
  name              = "/aws/lambda/${local.name_prefix}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = { Name = "${local.name_prefix}-logs" }
}

# ---- Dead-Letter Queue --------------------------------------
resource "aws_sqs_queue" "dlq" {
  name                      = "${local.name_prefix}-dlq"
  message_retention_seconds = 1209600  # 14 days
  kms_master_key_id         = var.kms_key_arn != "" ? var.kms_key_arn : "alias/aws/sqs"

  tags = { Name = "${local.name_prefix}-dlq" }
}

# ---- Security Group (VPC mode) ------------------------------
resource "aws_security_group" "lambda" {
  count  = local.has_vpc_config ? 1 : 0
  name   = "${local.name_prefix}-lambda-sg"
  vpc_id = var.vpc_id

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name_prefix}-lambda-sg" }
}

# ---- Execution Role -----------------------------------------
resource "aws_iam_role" "lambda" {
  name = "${local.name_prefix}-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "${local.name_prefix}-exec-role" }
}

resource "aws_iam_role_policy_attachment" "basic_execution" {
  role       = aws_iam_role.lambda.name
  policy_arn = local.has_vpc_config ? "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole" : "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "xray" {
  name = "${local.name_prefix}-xray"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["xray:PutTraceSegments", "xray:PutTelemetryRecords"]
      Resource = "*"
    }, {
      Effect   = "Allow"
      Action   = ["sqs:SendMessage"]
      Resource = aws_sqs_queue.dlq.arn
    }, {
      Effect   = "Allow"
      Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
      Resource = var.kms_key_arn != "" ? [var.kms_key_arn] : ["*"]
    }]
  })
}

resource "aws_iam_role_policy" "custom" {
  count  = var.custom_policy != "" ? 1 : 0
  name   = "${local.name_prefix}-custom"
  role   = aws_iam_role.lambda.id
  policy = var.custom_policy
}

# ---- Lambda Function ----------------------------------------
resource "aws_lambda_function" "main" {
  function_name = local.name_prefix
  description   = coalesce(var.description, "${var.function_name} function for ${var.environment}")
  role          = aws_iam_role.lambda.arn
  runtime       = var.runtime
  handler       = var.handler
  timeout       = var.timeout
  memory_size   = var.memory_size
  architectures = var.architectures

  filename         = var.filename != "" ? var.filename : null
  image_uri        = var.image_uri != "" ? var.image_uri : null
  package_type     = var.image_uri != "" ? "Image" : "Zip"
  source_code_hash = var.filename != "" ? filebase64sha256(var.filename) : null

  reserved_concurrent_executions = var.reserved_concurrency

  kms_key_arn = var.kms_key_arn != "" ? var.kms_key_arn : null

  environment {
    variables = var.environment_variables
  }

  tracing_config {
    mode = "Active"
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.dlq.arn
  }

  dynamic "vpc_config" {
    for_each = local.has_vpc_config ? [1] : []
    content {
      subnet_ids         = var.subnet_ids
      security_group_ids = [aws_security_group.lambda[0].id]
    }
  }

  tags = { Name = local.name_prefix }

  depends_on = [
    aws_cloudwatch_log_group.function,
    aws_iam_role_policy_attachment.basic_execution
  ]
}
