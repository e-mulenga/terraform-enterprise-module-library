# Operational Runbook
## Terraform Enterprise Module Library

**Portfolio:** Enterprise Cloud Platform — Position 2 of 6
**Owner:** Platform Engineering
**Cadence:** Review quarterly; update on every major/minor version release

---

## Overview

This runbook covers routine operational tasks for maintaining and evolving the module library. Because this library is consumed by multiple downstream repositories, every change procedure here follows a change-then-notify pattern: make the change, tag a version, then notify downstream repos to update their `?ref=` pin.

---

## Section 1: Releasing a New Module Version

### 1.1 Standard Release (Minor / Patch)

```bash
# 1. Merge PR to main — the release.yml workflow auto-increments the version

# 2. Confirm the tag was created
git fetch --tags
git describe --tags --abbrev=0
# e.g. v2.3.1

# 3. Announce in the platform Slack channel
# Template:
# 🚀 terraform-enterprise-module-library v2.3.1 released
# Changed: [module] — [what changed]
# Action: downstream repos must update ?ref= in next sprint
# PR template: https://github.com/your-org/terraform-enterprise-module-library/releases/tag/v2.3.1
```

### 1.2 Breaking Change Release (Major Version)

```bash
# 1. Add migration guide to CHANGELOG.md BEFORE merging
cat >> CHANGELOG.md << 'EOF'

## v3.0.0 — BREAKING CHANGES

### vpc module
- REMOVED: `enable_nat` variable (NAT Gateway now always provisioned in prod)
- ADDED: `single_nat_gateway` variable (default: false for prod, recommended true for dev)

### Migration steps
1. Remove `enable_nat = true` from all callers
2. Add `single_nat_gateway = false` (or `true` for dev cost saving)
3. terraform plan — expect no resource changes if previously enable_nat=true
EOF

# 2. Label the PR with "breaking-change" to trigger major version bump

# 3. After merge, open PRs in all downstream repos
# aws-devsecops-pipeline       → update vpc, rds, lambda ?ref=
# aws-secure-eks-platform      → update vpc, eks, alb, rds ?ref=
# aws-cloud-security-operations-center → update kms, guardduty, security-hub ?ref=
# multi-cloud-governance        → update security-hub ?ref=
```

### 1.3 Hotfix Release (Patch — Security Fix)

```bash
# 1. Branch from the latest tag, not main
git checkout -b hotfix/vpc-flow-log-encryption v2.3.0

# 2. Apply the fix
# 3. PR targeting main (not develop) — label with "bug"
# 4. After merge, release.yml creates a patch tag (v2.3.1)
# 5. Notify downstream repos immediately via Slack and email
```

---

## Section 2: Adding a New Module

### 2.1 Module Creation Checklist

```bash
MODULE_NAME="elasticache"  # replace with your module name

# 1. Create directory structure
mkdir -p modules/${MODULE_NAME}
touch modules/${MODULE_NAME}/{main.tf,variables.tf,outputs.tf}

# 2. Write main.tf — follow the security-defaults checklist:
# ✅ KMS encryption on all data at rest
# ✅ No public access by default
# ✅ VPC-deployed resources in private/intra subnets
# ✅ CloudWatch monitoring resources included
# ✅ for_each over count for named resources
# ✅ prevent_destroy on critical resources

# 3. Write variables.tf
# ✅ All variables have type, description, and default or explicit required
# ✅ No hardcoded: account IDs, regions, emails, passwords
# ✅ Sensitive variables marked sensitive = true

# 4. Write outputs.tf
# ✅ All outputs have description
# ✅ Sensitive outputs marked sensitive = true

# 5. Add to examples/dev/main.tf
# 6. Run validation
bash validation/validate-modules.sh

# 7. Update README.md — Module section and AWS Services table
# 8. Update architecture/service-selection-rationale.md
# 9. PR with "enhancement" label → triggers minor version bump
```

---

## Section 3: Updating an Existing Module

### 3.1 Non-Breaking Update

```bash
# 1. Create feature branch
git checkout -b feat/rds-performance-insights

# 2. Make changes to modules/rds/main.tf
# 3. Run validation locally
bash validation/validate-modules.sh

# 4. Security scan
tfsec modules/rds/ --minimum-severity HIGH
checkov -d modules/rds/ --framework terraform

# 5. PR with "enhancement" label (minor bump) or "bug" (patch bump)
```

### 3.2 Variable Deprecation

When removing or renaming a variable:

```hcl
# modules/rds/variables.tf
# Step 1: Mark old variable as deprecated with a description warning
variable "enable_multi_az" {
  type        = bool
  description = "DEPRECATED — use multi_az instead. Will be removed in v4.0.0."
  default     = null
}

# Step 2: Add new variable
variable "multi_az" {
  type        = bool
  description = "Enable Multi-AZ for RDS instance."
  default     = true
}

# Step 3: In main.tf — honour both for one major version
# multi_az = coalesce(var.multi_az, var.enable_multi_az, true)
```

---

## Section 4: Testing a Module Change Locally

```bash
# Quick local test cycle
cd modules/rds

# Format
terraform fmt

# Init (no backend needed for validate)
terraform init -backend=false -input=false

# Validate
terraform validate

# Security scan
tfsec . --minimum-severity HIGH

# Check for secrets
gitleaks detect --source . --verbose

# Return to repo root
cd ../../
```

---

## Section 5: Validating Downstream Impact

Before merging any module change, check which downstream repos reference it:

```bash
MODULE="vpc"

echo "Repos referencing modules/${MODULE}:"
# Search GitHub (requires gh CLI)
gh search code \
  --owner your-org \
  "terraform-enterprise-module-library//modules/${MODULE}" \
  --json repository \
  | jq -r '.[].repository.nameWithOwner'
```

Expected output for `vpc`:
```
your-org/aws-devsecops-pipeline
your-org/aws-secure-eks-platform
```

For each listed repo, open a PR after the release tag is created.

---

## Section 6: Maintenance Schedule

| Task | Frequency | Owner | Tool |
|---|---|---|---|
| Review open security scan findings | Weekly | Platform Eng | GitHub Security tab |
| Bump AWS provider minor version | Monthly | Platform Eng | PR + release |
| Review module usage across portfolio | Monthly | Platform Eng | gh search |
| Deprecation notice follow-up | Per release | Platform Eng | CHANGELOG.md |
| Validate all modules pass tfsec | On every PR | Automated | CI/CD |
| Runbook review | Quarterly | Platform Eng | Manual |
| Full portfolio dependency audit | Quarterly | Cloud Architect | Manual |

---

## Section 7: Common Issues

### `terraform validate` fails on a module with no backend

```bash
# Modules must not have a backend block — they are consumed, not run directly
# If you see: "No configuration files", ensure you're in the module directory
# If you see provider errors, it's expected — validate ignores provider resolution
terraform init -backend=false && terraform validate
```

### `tfsec` reports a false positive

```bash
# Add an inline ignore comment (document the reason)
resource "aws_s3_bucket" "main" {
  # tfsec:ignore:aws-s3-enable-bucket-logging — access logging to dedicated bucket handled by caller
  bucket = var.bucket_name
}
```

### Module version pin conflict between downstream repos

```
Repo A uses: ?ref=v2.1.0 (vpc module)
Repo B uses: ?ref=v2.3.0 (vpc module)
```

This is expected and safe — each consumer pins independently. Encourage upgrades via quarterly dependency audit PRs. Never force a specific version across all consumers simultaneously.

---

*Reviewed: Quarterly | Owner: Platform Engineering*
