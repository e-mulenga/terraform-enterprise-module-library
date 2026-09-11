# ============================================================
# examples/prod — Module Library Production Example
# ============================================================
# Full HA composition with 3 AZs, per-AZ NAT Gateways,
# Multi-AZ RDS, private EKS cluster, and WAF-protected ALB.
# All resources use CMK encryption.
# ============================================================

# ---- KMS Keys (per service) ---------------------------------
module "kms_vpc" {
  source            = "../../modules/kms"
  organization_name = var.organization_name
  environment       = var.environment
  purpose           = "vpc-flow-logs"
  enable_rotation   = true
}

module "kms_rds" {
  source             = "../../modules/kms"
  organization_name  = var.organization_name
  environment        = var.environment
  purpose            = "rds"
  enable_rotation    = true
  service_principals = ["rds.amazonaws.com"]
  multi_region       = true   # Enable DR decryption
}

module "kms_eks" {
  source            = "../../modules/kms"
  organization_name = var.organization_name
  environment       = var.environment
  purpose           = "eks-secrets"
  enable_rotation   = true
}

module "kms_lambda" {
  source            = "../../modules/kms"
  organization_name = var.organization_name
  environment       = var.environment
  purpose           = "lambda-env"
  enable_rotation   = true
}

# ---- Network ------------------------------------------------
module "vpc" {
  source = "../../modules/vpc"

  organization_name       = var.organization_name
  environment             = var.environment
  vpc_cidr                = var.vpc_cidr
  az_count                = 3
  single_nat_gateway      = false    # HA: one NAT per AZ
  flow_log_retention_days = 365
  kms_key_arn             = module.kms_vpc.key_arn
}

# ---- Storage ------------------------------------------------
module "app_bucket" {
  source = "../../modules/s3"

  bucket_name        = "${var.organization_name}-${var.environment}-app-artifacts"
  purpose            = "application-artifacts"
  kms_key_arn        = module.kms_eks.key_arn
  versioning_enabled = true

  lifecycle_rules = [{
    id          = "tiered-storage"
    transitions = [
      { days = 90,  storage_class = "STANDARD_IA" },
      { days = 365, storage_class = "GLACIER" }
    ]
    expiration_days = 2557
  }]
}

module "alb_logs_bucket" {
  source = "../../modules/s3"

  bucket_name        = "${var.organization_name}-${var.environment}-alb-logs"
  purpose            = "alb-access-logs"
  versioning_enabled = false
  lifecycle_rules = [{
    id              = "expire-logs"
    expiration_days = 90
  }]
}

# ---- Security Services --------------------------------------
module "cloudtrail" {
  source = "../../modules/cloudtrail"

  organization_name  = var.organization_name
  environment        = var.environment
  s3_bucket_name     = var.cloudtrail_bucket
  kms_key_arn        = module.kms_vpc.key_arn
  log_retention_days = 365
  is_multi_region    = true
}

module "guardduty" {
  source = "../../modules/guardduty"

  organization_name = var.organization_name
  environment       = var.environment
  enabled           = true
}

module "security_hub" {
  source = "../../modules/security-hub"

  organization_name = var.organization_name
  environment       = var.environment
}

# ---- Database -----------------------------------------------
module "primary_db" {
  source = "../../modules/rds"

  organization_name         = var.organization_name
  environment               = var.environment
  name                      = "primary"
  vpc_id                    = module.vpc.vpc_id
  subnet_ids                = module.vpc.intra_subnet_ids
  kms_key_arn               = module.kms_rds.key_arn
  engine                    = "postgres"
  engine_version            = "15.5"
  instance_class            = "db.r6g.large"
  parameter_group_family    = "postgres15"
  multi_az                  = true
  allocated_storage         = 200
  max_allocated_storage     = 2000
  backup_retention_days     = 35
  alarm_sns_topic_arns      = [module.guardduty.findings_topic_arn]
  master_password           = var.db_master_password
  allowed_security_group_ids = [module.eks_cluster.cluster_security_group_id]
}

# ---- Container Platform -------------------------------------
module "eks_cluster" {
  source = "../../modules/eks"

  organization_name     = var.organization_name
  environment           = var.environment
  cluster_name          = "platform"
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  kms_key_arn           = module.kms_eks.key_arn
  kubernetes_version    = "1.29"
  enable_public_endpoint = false   # Prod: private API endpoint only
  log_retention_days    = 365

  node_groups = {
    general = {
      instance_types = ["m6g.xlarge"]
      desired_size   = 3
      min_size       = 3
      max_size       = 10
    }
    compute = {
      instance_types = ["c6g.2xlarge"]
      desired_size   = 2
      min_size       = 0
      max_size       = 20
    }
  }
}

# ---- Load Balancer ------------------------------------------
module "api_alb" {
  source = "../../modules/alb"

  organization_name         = var.organization_name
  environment               = var.environment
  name                      = "api"
  vpc_id                    = module.vpc.vpc_id
  public_subnet_ids         = module.vpc.public_subnet_ids
  private_subnet_ids        = module.vpc.private_subnet_ids
  target_security_group_ids = [module.eks_cluster.cluster_security_group_id]
  certificate_arn           = var.acm_certificate_arn
  access_log_bucket         = module.alb_logs_bucket.bucket_name
  target_port               = 8080
  health_check_path         = "/healthz"
}

# ============================================================
# Variables
# ============================================================
variable "organization_name"    { type = string }
variable "environment"          { type = string; default = "prod" }
variable "vpc_cidr"             { type = string; default = "10.30.0.0/16" }
variable "cloudtrail_bucket"    { type = string }
variable "acm_certificate_arn"  { type = string }
variable "db_master_password"   { type = string; sensitive = true }
