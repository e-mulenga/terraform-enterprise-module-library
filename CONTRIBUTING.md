# Contributing Guide
## Terraform Enterprise Module Library

This library is **position 2 of 6** in the Enterprise Cloud Platform Portfolio. Every module here is consumed by multiple downstream repositories — changes here have wide blast radius.

---

## Portfolio Impact Matrix

| Module | Downstream Consumers |
|---|---|
| `vpc` | aws-devsecops-pipeline, aws-secure-eks-platform |
| `eks` | aws-secure-eks-platform |
| `rds` | aws-devsecops-pipeline, aws-secure-eks-platform |
| `kms` | All downstream repos |
| `guardduty`, `security-hub` | aws-cloud-security-operations-center |
| `s3` | All downstream repos |

**Breaking changes require:**
1. Major version bump (see release.yml)
2. Migration guide in `CHANGELOG.md`
3. PR opened in each consuming repo with the updated `?ref=` pin
4. Sign-off from security team

---

## Module Standards Checklist

Every new module must satisfy all of these before merging:

- [ ] `main.tf`, `variables.tf`, `outputs.tf` — all present
- [ ] No hardcoded account IDs, regions, emails, or passwords
- [ ] All variables have `type`, `description`, and `default` (or explicit required)
- [ ] Sensitive outputs marked `sensitive = true`
- [ ] Security defaults ON — encryption, TLS, access logging enabled without opt-in
- [ ] `for_each` used over `count` for named resources
- [ ] `prevent_destroy = true` on critical resources
- [ ] Module passes `terraform validate`
- [ ] Module passes `tfsec` with no HIGH/CRITICAL findings
- [ ] Module passes `checkov` with no HIGH/CRITICAL findings
- [ ] Example added to `examples/dev/main.tf`
- [ ] Module documented in README.md (Terraform Structure + AWS Services Used sections)
- [ ] Version tag created following semantic versioning

---

## Branch & PR Workflow

```
feature/<module-name>  →  main (requires 2 approvals, security review for kms/iam/scp)
```

**PR labels control the version bump:**
- `enhancement` → minor version
- `bug` or `fix` → patch version
- `breaking-change` → major version (requires migration guide)

---

## Local Development

```bash
# Format
terraform fmt -recursive modules/

# Validate all
bash validation/validate-modules.sh

# Security scan
tfsec modules/ --minimum-severity HIGH
checkov -d modules/ --framework terraform

# Secret scan
gitleaks detect --source . --verbose
```
