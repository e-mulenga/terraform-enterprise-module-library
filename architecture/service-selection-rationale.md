# Service Selection Rationale
## Terraform Enterprise Module Library

> This document maps every module to its business, security, operational, and compliance justification, and records the alternatives considered.

---

## Module: vpc

### Why Selected
A VPC is the network boundary for every AWS workload. This module enforces the enterprise three-tier pattern (public → private → intra) automatically — consuming engineers cannot accidentally deploy a database into a public subnet.

### Problem It Solves
- **Business:** Provides network isolation between environments and between tiers within an environment.
- **Technical:** Prevents lateral movement between application and database tiers; isolates internet-facing from internal resources.

### Alternatives Considered
| Alternative | Why Rejected |
|---|---|
| AWS-managed VPC (default VPC) | No subnet tiers, no flow logs, public by default |
| Single-tier VPC (all subnets same) | No blast-radius control; databases reachable from web tier |
| Transit Gateway only | Still requires per-account VPC design |

### Well-Architected Alignment
- **Security:** Network segmentation, flow logs on ALL traffic, denied-by-default security group
- **Reliability:** Multi-AZ subnets, one NAT per AZ in prod (HA)
- **Performance Efficiency:** Three AZs provide zonal balancing for ELB targets
- **Cost Optimization:** `single_nat_gateway` variable enables dev cost reduction

---

## Module: iam

### Why Selected
IAM roles are the identity primitive for all AWS service interactions. This module standardises the role creation pattern — ensuring permission boundaries, consistent naming, and no inline-only policies that are invisible to IAM Access Analyzer.

### Problem It Solves
- **Business:** Consistent IAM governance across all workloads.
- **Security:** Permission boundary support prevents privilege escalation through role assumption.
- **Operational:** `create_instance_profile` flag eliminates a separate module call for EC2-attached roles.

### Well-Architected Alignment
- **Security:** Least privilege by design; permission boundary as ceiling
- **Operational Excellence:** Factory pattern eliminates inconsistent role creation

---

## Module: kms

### Why Selected
Every data store in the portfolio must use a customer-managed KMS key — not an AWS-managed key — to enable: (a) key policy control, (b) key-level CloudTrail audit, and (c) the ability to deny decryption via key policy conditions.

### Problem It Solves
AWS-managed keys (`aws/s3`, `aws/rds`) are shared across the account and controlled by AWS. A CMK is owned and governed by the customer — you can rotate it, restrict who can use it, and audit every use in CloudTrail.

### Alternatives Considered
| Alternative | Why Rejected |
|---|---|
| AWS managed keys | No customer key policy control; shared across account |
| CloudHSM | FIPS 140-3 Level 3 compliance warranted only for card data / HSM-required workloads; 10× cost |
| No encryption | Unacceptable for enterprise production |

### Well-Architected Alignment
- **Security:** Encryption at rest with customer-controlled key lifecycle and audit
- **Cost Optimization:** $1/key/month; `bucket_key_enabled = true` reduces per-request costs by up to 99%

---

## Module: s3

### Why Selected
S3 is used for artifacts, logs, backups, and data lakes across every portfolio repo. Without a hardened module, teams omit block-public-access, skip encryption, or miss lifecycle rules — leading to cost overrun or data exposure.

### Security Controls Built In
1. Block-public-access — all four settings, non-overridable
2. TLS-only bucket policy — denies non-HTTPS requests
3. KMS encryption — bucket-key enabled for cost efficiency
4. S3 access logging — to a separate access-log bucket
5. Versioning — enabled by default for audit and recovery

### Well-Architected Alignment
- **Security:** Public access blocked, encryption enforced, TLS required
- **Cost Optimization:** Lifecycle rules tier data to STANDARD_IA and GLACIER automatically
- **Reliability:** Versioning enables point-in-time object recovery

---

## Module: rds

### Why Selected
RDS provides managed relational databases with automated backups, Multi-AZ failover, and native KMS encryption. The module adds Secrets Manager credential management (no plaintext passwords), Enhanced Monitoring, Performance Insights, and CloudWatch alarms.

### Problem It Solves
Teams manually provisioning RDS frequently: (a) put it in a public subnet, (b) store the master password in tfvars, (c) skip Multi-AZ. This module makes all three impossible without explicit override.

### Alternatives Considered
| Alternative | Why Rejected |
|---|---|
| Self-managed EC2 PostgreSQL | No managed backups, patching, or Multi-AZ; operational burden |
| Aurora Serverless v2 | Viable; module can be extended — see Future Enhancements |
| DynamoDB | Not relational; different access pattern |

### Well-Architected Alignment
- **Security:** No public access, KMS encryption, Secrets Manager credentials, intra-subnet placement
- **Reliability:** Multi-AZ enabled in prod, automated backups, deletion protection
- **Operational Excellence:** Enhanced Monitoring and Performance Insights reduce MTTR

---

## Module: eks

### Why Selected
EKS provides a managed Kubernetes control plane with native AWS integrations (IAM, KMS, VPC, ALB, CloudWatch). The module enforces private API endpoint, envelope encryption for secrets, IMDSv2 on nodes, and IRSA (IAM Roles for Service Accounts) via OIDC.

### Problem It Solves
Self-managed Kubernetes (kOps, kubeadm) requires managing etcd, control plane HA, and certificate rotation. EKS offloads these to AWS, leaving the platform team to focus on node groups, add-ons, and workload security.

### Security Controls Built In
1. Private API endpoint — no public Kubernetes API exposure
2. KMS envelope encryption on `secrets` resource type
3. IMDSv2 enforced on all node launch templates
4. Encrypted root EBS volumes on nodes
5. Full control plane logging (api, audit, authenticator, controller, scheduler)
6. IRSA via OIDC — workload pods get scoped IAM roles, not node instance role

### Well-Architected Alignment
- **Security:** Private control plane, encrypted secrets, pod-level IAM via IRSA
- **Reliability:** Managed node groups with auto-scaling; control plane HA by default
- **Performance Efficiency:** Spot capacity_type option for non-critical node groups

---

## Module: alb

### Why Selected
The Application Load Balancer is the ingress point for all HTTP/HTTPS traffic. The module enforces TLS termination with TLS 1.3 preferred, HTTP → HTTPS redirect, WAF v2 with AWS Managed Rules, and S3 access logging.

### WAF Managed Rules Applied
1. `AWSManagedRulesCommonRuleSet` — OWASP Top 10 (SQLi, XSS, LFI, RFI)
2. `AWSManagedRulesKnownBadInputsRuleSet` — Log4Shell, CVE-specific patterns
3. `AWSManagedRulesAmazonIpReputationList` — Block known malicious IPs

### Alternatives Considered
| Alternative | Why Rejected |
|---|---|
| CloudFront + WAF | Adds caching layer not always needed; more complex TF |
| NLB | No WAF support; Layer 4 only |
| API Gateway | Purpose-specific; not general web traffic |

### Well-Architected Alignment
- **Security:** WAF prevents web attacks; TLS 1.3; no HTTP without redirect
- **Reliability:** Cross-zone load balancing across all AZs
- **Performance Efficiency:** HTTP/2 enabled; connection reuse

---

## Module: lambda

### Why Selected
Lambda is the preferred compute for event-driven workloads — CI/CD hooks, security remediations, scheduled tasks, and API handlers. The module adds VPC deployment, KMS-encrypted environment variables, X-Ray tracing, DLQ, and reserved concurrency.

### Problem It Solves
Lambda functions deployed without VPC access cannot reach private RDS or internal services. Functions without reserved concurrency can exhaust account concurrency and starve other functions. Functions without DLQ silently drop failed invocations.

### Well-Architected Alignment
- **Security:** VPC deployment, KMS env var encryption, least-privilege execution role
- **Reliability:** DLQ captures all failed invocations; reserved concurrency prevents noisy-neighbour
- **Cost Optimization:** ARM64 (Graviton) architecture 20% cheaper than x86 for equivalent performance
- **Sustainability:** ARM64 uses less power per compute unit

---

## Module: guardduty

### Why Selected
GuardDuty detects active threats that security configuration controls cannot — credential compromise, exfiltration via DNS, C2 communication, compromised EC2 instances. It requires no agents, no infrastructure, and processes CloudTrail, VPC Flow Logs, DNS, S3, and EKS audit logs.

### Well-Architected Alignment
- **Security:** Runtime threat detection complementing preventive SCPs and Config rules
- **Cost Optimization:** Volume-based pricing, no compute overhead

---

## Module: security-hub

### Why Selected
Security Hub aggregates findings from GuardDuty, Config, Inspector, Access Analyzer, and third-party tools into a single normalised feed. It provides a compliance score against CIS AWS Foundations v1.4, FSBP, and NIST 800-53 — giving the security team a dashboard of posture rather than N separate service consoles.

### Standards Enabled
- CIS AWS Foundations Benchmark v1.4.0
- AWS Foundational Security Best Practices (FSBP) v1.0.0
- NIST SP 800-53 Rev. 5

### Well-Architected Alignment
- **Security:** Consolidated compliance posture; automated CRITICAL/HIGH alerting
- **Operational Excellence:** Single security score drives remediation prioritisation

---

*Document owner: Cloud Security & Platform Engineering | Review: Quarterly*
