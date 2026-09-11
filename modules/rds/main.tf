# ============================================================
# Module: rds — Enterprise RDS Instance (MySQL / PostgreSQL)
# ============================================================
# WAF Pillars: Security, Reliability, Cost Optimization
#
# Provisions an encrypted, multi-AZ RDS instance:
#   - Credentials in AWS Secrets Manager (no tfvars plaintext)
#   - KMS encryption at rest
#   - Enhanced Monitoring + Performance Insights
#   - Automated backups with configurable retention
#   - Deployed in intra subnets (no internet route)
#   - Deletion protection enabled in prod
# ============================================================

data "aws_caller_identity" "current" {}

locals {
  name_prefix = "${var.organization_name}-${var.environment}-${var.name}"
}

# ---- Subnet Group -------------------------------------------
resource "aws_db_subnet_group" "main" {
  name        = "${local.name_prefix}-subnet-group"
  description = "Subnet group for ${local.name_prefix}"
  subnet_ids  = var.subnet_ids

  tags = { Name = "${local.name_prefix}-subnet-group" }
}

# ---- Parameter Group ----------------------------------------
resource "aws_db_parameter_group" "main" {
  name        = "${local.name_prefix}-params"
  family      = var.parameter_group_family
  description = "Parameter group for ${local.name_prefix}"

  dynamic "parameter" {
    for_each = var.parameters
    content {
      name         = parameter.value.name
      value        = parameter.value.value
      apply_method = try(parameter.value.apply_method, "immediate")
    }
  }

  tags = { Name = "${local.name_prefix}-params" }
}

# ---- Security Group -----------------------------------------
resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-sg"
  description = "RDS security group — allow only from app tier"
  vpc_id      = var.vpc_id

  ingress {
    description     = "DB port from app security group"
    from_port       = var.port
    to_port         = var.port
    protocol        = "tcp"
    security_groups = var.allowed_security_group_ids
  }

  egress {
    description = "Allow all outbound (patch updates via NAT)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name_prefix}-sg" }
}

# ---- Secrets Manager — master credentials -------------------
resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${local.name_prefix}/db-credentials"
  description             = "Master credentials for ${local.name_prefix} RDS instance"
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = var.environment == "prod" ? 30 : 7

  tags = { Name = "${local.name_prefix}-db-credentials" }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.master_username
    password = var.master_password
    engine   = var.engine
    host     = aws_db_instance.main.address
    port     = var.port
    dbname   = var.db_name
  })

  lifecycle { ignore_changes = [secret_string] }
}

# ---- RDS Instance -------------------------------------------
resource "aws_db_instance" "main" {
  identifier     = local.name_prefix
  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class

  db_name  = var.db_name
  username = var.master_username
  password = var.master_password
  port     = var.port

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = var.kms_key_arn

  multi_az               = var.multi_az
  publicly_accessible    = false
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.main.name

  backup_retention_period   = var.backup_retention_days
  backup_window             = "02:00-03:00"
  maintenance_window        = "sun:04:00-sun:05:00"
  copy_tags_to_snapshot     = true
  skip_final_snapshot       = var.environment != "prod"
  final_snapshot_identifier = var.environment == "prod" ? "${local.name_prefix}-final-snapshot" : null
  deletion_protection       = var.environment == "prod"

  auto_minor_version_upgrade = true
  apply_immediately          = var.environment != "prod"

  monitoring_interval             = 60
  monitoring_role_arn             = aws_iam_role.rds_monitoring.arn
  performance_insights_enabled    = true
  performance_insights_kms_key_id = var.kms_key_arn
  performance_insights_retention_period = var.environment == "prod" ? 731 : 7

  enabled_cloudwatch_logs_exports = var.cloudwatch_log_exports

  tags = {
    Name        = local.name_prefix
    BackupEnabled = "true"
  }

  lifecycle {
    prevent_destroy = false
    ignore_changes  = [password]
  }
}

# ---- Enhanced Monitoring Role -------------------------------
resource "aws_iam_role" "rds_monitoring" {
  name = "${local.name_prefix}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# ---- CloudWatch Alarms --------------------------------------
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${local.name_prefix}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "RDS CPU utilization > 80% for 10 minutes"
  dimensions          = { DBInstanceIdentifier = aws_db_instance.main.id }
  alarm_actions       = var.alarm_sns_topic_arns
  ok_actions          = var.alarm_sns_topic_arns
}

resource "aws_cloudwatch_metric_alarm" "storage_low" {
  alarm_name          = "${local.name_prefix}-storage-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 10737418240  # 10 GB in bytes
  alarm_description   = "RDS free storage < 10 GB"
  dimensions          = { DBInstanceIdentifier = aws_db_instance.main.id }
  alarm_actions       = var.alarm_sns_topic_arns
}
