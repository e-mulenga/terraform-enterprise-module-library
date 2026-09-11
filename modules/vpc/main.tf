# ============================================================
# Module: vpc — Enterprise VPC with multi-AZ subnets
# ============================================================
# Pillars: Security, Reliability, Performance Efficiency
#
# Creates a fully segmented VPC:
#   Public subnets    → NAT Gateways, ALBs
#   Private subnets   → Application workloads, EKS nodes
#   Intra subnets     → Databases, caches (no internet route)
#
# VPC Flow Logs are always enabled and delivered to a
# dedicated CloudWatch Log Group encrypted with the KMS key.
# ============================================================

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)
  name_prefix = "${var.organization_name}-${var.environment}"
}

# ---- VPC ----------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${local.name_prefix}-vpc" }
}

# ---- Internet Gateway ---------------------------------------
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.name_prefix}-igw" }
}

# ---- Public Subnets -----------------------------------------
resource "aws_subnet" "public" {
  count                   = length(local.azs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, count.index)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false   # Explicit assignment only

  tags = {
    Name                     = "${local.name_prefix}-public-${local.azs[count.index]}"
    "kubernetes.io/role/elb" = "1"
    Tier                     = "public"
  }
}

# ---- Private Subnets (application) --------------------------
resource "aws_subnet" "private" {
  count             = length(local.azs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + length(local.azs))
  availability_zone = local.azs[count.index]

  tags = {
    Name                              = "${local.name_prefix}-private-${local.azs[count.index]}"
    "kubernetes.io/role/internal-elb" = "1"
    Tier                              = "private"
  }
}

# ---- Intra Subnets (database — no NAT route) ----------------
resource "aws_subnet" "intra" {
  count             = length(local.azs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + (length(local.azs) * 2))
  availability_zone = local.azs[count.index]

  tags = {
    Name = "${local.name_prefix}-intra-${local.azs[count.index]}"
    Tier = "intra"
  }
}

# ---- Elastic IPs for NAT ------------------------------------
resource "aws_eip" "nat" {
  count  = var.single_nat_gateway ? 1 : length(local.azs)
  domain = "vpc"

  tags = { Name = "${local.name_prefix}-nat-eip-${count.index + 1}" }
}

# ---- NAT Gateways -------------------------------------------
resource "aws_nat_gateway" "main" {
  count         = var.single_nat_gateway ? 1 : length(local.azs)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = { Name = "${local.name_prefix}-nat-${count.index + 1}" }

  depends_on = [aws_internet_gateway.main]
}

# ---- Route Tables -------------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.name_prefix}-public-rt" }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "public" {
  count          = length(local.azs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  count  = var.single_nat_gateway ? 1 : length(local.azs)
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.name_prefix}-private-rt-${count.index + 1}" }

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[var.single_nat_gateway ? 0 : count.index].id
  }
}

resource "aws_route_table_association" "private" {
  count          = length(local.azs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[var.single_nat_gateway ? 0 : count.index].id
}

resource "aws_route_table" "intra" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.name_prefix}-intra-rt" }
  # No routes — intra subnets are isolated
}

resource "aws_route_table_association" "intra" {
  count          = length(local.azs)
  subnet_id      = aws_subnet.intra[count.index].id
  route_table_id = aws_route_table.intra.id
}

# ---- VPC Flow Logs ------------------------------------------
resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/aws/vpc/flowlogs/${local.name_prefix}"
  retention_in_days = var.flow_log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = { Name = "${local.name_prefix}-flow-logs" }
}

resource "aws_iam_role" "flow_logs" {
  name = "${local.name_prefix}-vpc-flow-log-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "flow_logs" {
  name = "vpc-flow-log-delivery"
  role = aws_iam_role.flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup", "logs:CreateLogStream",
        "logs:PutLogEvents", "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "${aws_cloudwatch_log_group.flow_logs.arn}:*"
    }]
  })
}

resource "aws_flow_log" "main" {
  iam_role_arn    = aws_iam_role.flow_logs.arn
  log_destination = aws_cloudwatch_log_group.flow_logs.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id

  tags = { Name = "${local.name_prefix}-flow-log" }
}

# ---- Default Security Group (deny all) ----------------------
resource "aws_default_security_group" "deny_all" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.name_prefix}-default-sg-deny-all" }
  # No ingress or egress rules = deny all
}
