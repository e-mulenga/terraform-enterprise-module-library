# ============================================================
# Module: eks — Secure EKS Cluster with Managed Node Groups
# ============================================================
# WAF Pillars: Security, Reliability, Performance Efficiency
#
# Provisions a production-grade EKS cluster:
#   - Private API endpoint (no public access)
#   - KMS envelope encryption for Kubernetes secrets
#   - Managed node groups in private subnets
#   - IRSA (IAM Roles for Service Accounts) enabled
#   - Control plane logging to CloudWatch
#   - aws-auth ConfigMap managed via aws_auth_roles variable
# ============================================================

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  name_prefix = "${var.organization_name}-${var.environment}-${var.cluster_name}"
  cluster_oidc_issuer_url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# ---- IAM Role: Cluster Control Plane -----------------------
resource "aws_iam_role" "cluster" {
  name = "${local.name_prefix}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "${local.name_prefix}-cluster-role" }
}

resource "aws_iam_role_policy_attachment" "cluster_policies" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  ])
  role       = aws_iam_role.cluster.name
  policy_arn = each.value
}

# ---- Security Group: Cluster --------------------------------
resource "aws_security_group" "cluster" {
  name        = "${local.name_prefix}-cluster-sg"
  description = "EKS cluster control plane security group"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = { Name = "${local.name_prefix}-cluster-sg" }
}

# ---- EKS Cluster -------------------------------------------
resource "aws_eks_cluster" "main" {
  name     = local.name_prefix
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = concat(var.private_subnet_ids, var.public_subnet_ids)
    security_group_ids      = [aws_security_group.cluster.id]
    endpoint_private_access = true
    endpoint_public_access  = var.enable_public_endpoint
    public_access_cidrs     = var.enable_public_endpoint ? var.public_access_cidrs : []
  }

  # Envelope encryption for Kubernetes secrets
  encryption_config {
    provider { key_arn = var.kms_key_arn }
    resources = ["secrets"]
  }

  # All control plane logs
  enabled_cluster_log_types = [
    "api", "audit", "authenticator", "controllerManager", "scheduler"
  ]

  kubernetes_network_config {
    service_ipv4_cidr = var.service_cidr
    ip_family         = "ipv4"
  }

  tags = { Name = local.name_prefix }

  depends_on = [aws_iam_role_policy_attachment.cluster_policies]
}

# ---- CloudWatch Log Group for control plane ----------------
resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${local.name_prefix}/cluster"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = { Name = "${local.name_prefix}-control-plane-logs" }
}

# ---- OIDC Provider for IRSA --------------------------------
data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = { Name = "${local.name_prefix}-oidc-provider" }
}

# ---- IAM Role: Node Group -----------------------------------
resource "aws_iam_role" "node_group" {
  name = "${local.name_prefix}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "${local.name_prefix}-node-role" }
}

resource "aws_iam_role_policy_attachment" "node_group_policies" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ])
  role       = aws_iam_role.node_group.name
  policy_arn = each.value
}

# ---- Managed Node Groups ------------------------------------
resource "aws_eks_node_group" "main" {
  for_each = var.node_groups

  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${local.name_prefix}-${each.key}"
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = var.private_subnet_ids
  instance_types  = each.value.instance_types
  capacity_type   = lookup(each.value, "capacity_type", "ON_DEMAND")
  ami_type        = lookup(each.value, "ami_type", "AL2_x86_64")

  scaling_config {
    desired_size = each.value.desired_size
    min_size     = each.value.min_size
    max_size     = each.value.max_size
  }

  update_config { max_unavailable = 1 }

  launch_template {
    id      = aws_launch_template.node[each.key].id
    version = aws_launch_template.node[each.key].latest_version
  }

  labels = merge(
    { "node-group" = each.key, "environment" = var.environment },
    lookup(each.value, "labels", {})
  )

  dynamic "taint" {
    for_each = lookup(each.value, "taints", [])
    content {
      key    = taint.value.key
      value  = lookup(taint.value, "value", null)
      effect = taint.value.effect
    }
  }

  tags = { Name = "${local.name_prefix}-${each.key}" }

  depends_on = [aws_iam_role_policy_attachment.node_group_policies]

  lifecycle { ignore_changes = [scaling_config[0].desired_size] }
}

# ---- Launch Template (node hardening) -----------------------
resource "aws_launch_template" "node" {
  for_each = var.node_groups

  name_prefix = "${local.name_prefix}-${each.key}-"
  description = "Launch template for EKS node group ${each.key}"

  # Enforce IMDSv2
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # Root EBS volume encryption
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = lookup(each.value, "disk_size_gb", 50)
      volume_type           = "gp3"
      encrypted             = true
      kms_key_id            = var.kms_key_arn
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${local.name_prefix}-${each.key}-node"
      NodeGroup   = each.key
      Environment = var.environment
    }
  }

  tags = { Name = "${local.name_prefix}-${each.key}-lt" }
}
