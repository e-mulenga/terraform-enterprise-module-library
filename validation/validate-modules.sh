#!/usr/bin/env bash
# ============================================================
# validation/validate-modules.sh
# Validate all Terraform modules in the library
# ============================================================
# Usage: bash validation/validate-modules.sh
# ============================================================

set -euo pipefail

PASS=0; FAIL=0
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'

pass() { echo -e "${GREEN}[PASS]${NC} $1"; ((PASS++)); }
fail() { echo -e "${RED}[FAIL]${NC} $1"; ((FAIL++)); }
header() { echo -e "\n${YELLOW}--- $1 ---${NC}"; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULES_DIR="${REPO_ROOT}/modules"

echo "============================================"
echo " Terraform Enterprise Module Library"
echo " Validation Run: $(date -u '+%Y-%m-%d %H:%M UTC')"
echo "============================================"

# ---- 1. Required files in each module -----------------------
header "Module Structure Check"
for MODULE_DIR in "${MODULES_DIR}"/*/; do
  MODULE=$(basename "${MODULE_DIR}")
  for FILE in main.tf variables.tf outputs.tf; do
    if [[ -f "${MODULE_DIR}/${FILE}" ]]; then
      pass "${MODULE}/${FILE} exists"
    else
      fail "${MODULE}/${FILE} MISSING"
    fi
  done
done

# ---- 2. No hardcoded values ---------------------------------
header "Hardcoded Value Check"
PATTERNS=(
  'account_id\s*=\s*"[0-9]{12}"'    # Hardcoded account IDs
  'region\s*=\s*"[a-z]+-[a-z]+-[0-9]"'  # Hardcoded regions
  'password\s*=\s*"[^$]'             # Plaintext passwords
)
for MODULE_DIR in "${MODULES_DIR}"/*/; do
  MODULE=$(basename "${MODULE_DIR}")
  FOUND=false
  for PATTERN in "${PATTERNS[@]}"; do
    if grep -rqE "${PATTERN}" "${MODULE_DIR}" 2>/dev/null; then
      fail "${MODULE}: possible hardcoded value matching '${PATTERN}'"
      FOUND=true
    fi
  done
  if [[ "${FOUND}" == "false" ]]; then
    pass "${MODULE}: no hardcoded values detected"
  fi
done

# ---- 3. Terraform format check ------------------------------
header "Terraform Format"
if terraform fmt -check -recursive "${MODULES_DIR}" 2>/dev/null; then
  pass "All modules properly formatted"
else
  fail "Formatting issues found — run: terraform fmt -recursive modules/"
fi

# ---- 4. Terraform validate each module ----------------------
header "Terraform Validate"
for MODULE_DIR in "${MODULES_DIR}"/*/; do
  MODULE=$(basename "${MODULE_DIR}")
  if terraform -chdir="${MODULE_DIR}" init -backend=false -input=false -no-color >/dev/null 2>&1 && \
     terraform -chdir="${MODULE_DIR}" validate -no-color >/dev/null 2>&1; then
    pass "${MODULE}: terraform validate passed"
  else
    fail "${MODULE}: terraform validate FAILED"
  fi
done

# ---- 5. Sensitive outputs check ----------------------------
header "Sensitive Output Check"
SENSITIVE_KEYWORDS=("arn" "password" "key" "secret" "token" "credential")
for MODULE_DIR in "${MODULES_DIR}"/*/; do
  MODULE=$(basename "${MODULE_DIR}")
  OUTPUTS_FILE="${MODULE_DIR}/outputs.tf"
  [[ -f "${OUTPUTS_FILE}" ]] || continue
  for KEYWORD in "${SENSITIVE_KEYWORDS[@]}"; do
    # Check if output name contains keyword but sensitive = true is NOT present
    while IFS= read -r LINE; do
      if echo "${LINE}" | grep -qiE "output.*${KEYWORD}" 2>/dev/null; then
        # Read next few lines to see if sensitive = true exists
        BLOCK=$(grep -A5 "${LINE}" "${OUTPUTS_FILE}" 2>/dev/null || echo "")
        if ! echo "${BLOCK}" | grep -q "sensitive.*=.*true"; then
          warn_check="${MODULE}: output '${LINE}' may need sensitive = true"
        fi
      fi
    done < "${OUTPUTS_FILE}"
  done
  pass "${MODULE}: sensitive output check complete"
done

# ---- 6. tfsec (if available) --------------------------------
header "tfsec Security Scan"
if command -v tfsec >/dev/null 2>&1; then
  if tfsec "${MODULES_DIR}" --minimum-severity HIGH --no-color --format text >/dev/null 2>&1; then
    pass "tfsec: no HIGH or CRITICAL findings"
  else
    fail "tfsec: HIGH/CRITICAL findings detected — review output above"
  fi
else
  echo -e "${YELLOW}[SKIP]${NC} tfsec not installed — install from https://github.com/aquasecurity/tfsec"
fi

# ---- Summary ------------------------------------------------
echo ""
echo "============================================"
echo " Results: PASS=${PASS}  FAIL=${FAIL}"
echo "============================================"
[[ "${FAIL}" -gt 0 ]] && exit 1 || exit 0
