# Security Policy
## Terraform Enterprise Module Library

## Reporting a Vulnerability

Report privately: **security@[your-org].com**  
Subject: `[SECURITY] terraform-enterprise-module-library — <description>`

**Do not** open public issues for security findings.

We acknowledge within **48 hours** and provide remediation timelines within **5 business days**.

---

## Security Defaults in This Library

All modules enforce these controls and cannot be disabled:

| Control | Modules | Mechanism |
|---|---|---|
| S3 block-public-access | s3 | `aws_s3_bucket_public_access_block` — all four settings |
| TLS-only S3 access | s3 | Bucket policy `aws:SecureTransport = false → Deny` |
| KMS encryption at rest | all | `kms_key_arn` required for all data stores |
| VPC Flow Logs | vpc | Always enabled, CloudWatch delivery |
| IMDSv2 enforcement | eks | Launch template `http_tokens = required` |
| RDS no public access | rds | `publicly_accessible = false` hardcoded |
| EKS private endpoint | eks | Configurable; docs warn against enabling public |
| WAF on ALB | alb | AWS Managed Rules: CRS, KBI, IP Reputation |

## Controls That CAN Be Disabled (with justification)

| Control | Variable | Default | Justification required |
|---|---|---|---|
| RDS Multi-AZ | `multi_az` | `true` | Cost (dev/test only) |
| Single NAT GW | `single_nat_gateway` | `false` | Cost (dev only) |
| Log retention | `log_retention_days` | varies | Budget constraint |

---

## Supported Versions

| Branch / Tag | Supported |
|---|---|
| `main` (latest) | ✅ |
| Latest minor tag (e.g. `v2.x`) | ✅ |
| Previous major (e.g. `v1.x`) | ❌ Upgrade required |
