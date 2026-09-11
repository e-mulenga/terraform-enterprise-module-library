#!/usr/bin/env bash
# ============================================================
# scripts/bootstrap-state.sh
# Bootstrap S3 + DynamoDB remote state for the module library
# ============================================================
# Run ONCE per environment before the first terraform init.
# Requires AdministratorAccess on the target account.
#
# Usage:
#   ENV=dev ORG=acme-enterprise AWS_REGION=af-south-1 \
#   bash scripts/bootstrap-state.sh
# ============================================================

set -euo pipefail

: "${ENV:?Required: ENV (dev|test|prod)}"
: "${ORG:?Required: ORG}"
: "${AWS_REGION:=${AWS_DEFAULT_REGION:-af-south-1}}"

BUCKET_NAME="${ORG}-tf-modules-state-${ENV}"
TABLE_NAME="${ORG}-tf-modules-lock-${ENV}"
KMS_ALIAS="alias/terraform-modules-state-key-${ENV}"

echo "=================================================="
echo " Bootstrapping module library state for: ${ENV}"
echo " Bucket  : ${BUCKET_NAME}"
echo " Table   : ${TABLE_NAME}"
echo " Region  : ${AWS_REGION}"
echo "=================================================="

# ---- KMS Key ------------------------------------------------
if aws kms describe-key --key-id "${KMS_ALIAS}" --region "${AWS_REGION}" &>/dev/null; then
  echo "[✓] KMS key already exists: ${KMS_ALIAS}"
  KEY_ID=$(aws kms describe-key --key-id "${KMS_ALIAS}" \
    --query 'KeyMetadata.KeyId' --output text --region "${AWS_REGION}")
else
  KEY_ID=$(aws kms create-key \
    --description "Terraform module library state key — ${ENV}" \
    --region "${AWS_REGION}" \
    --query 'KeyMetadata.KeyId' --output text)
  aws kms create-alias \
    --alias-name "${KMS_ALIAS}" \
    --target-key-id "${KEY_ID}" \
    --region "${AWS_REGION}"
  aws kms enable-key-rotation --key-id "${KEY_ID}" --region "${AWS_REGION}"
  echo "[✓] KMS key created: ${KMS_ALIAS}"
fi

# ---- S3 State Bucket ----------------------------------------
if aws s3api head-bucket --bucket "${BUCKET_NAME}" 2>/dev/null; then
  echo "[✓] State bucket already exists: ${BUCKET_NAME}"
else
  aws s3api create-bucket \
    --bucket "${BUCKET_NAME}" \
    --region "${AWS_REGION}" \
    --create-bucket-configuration LocationConstraint="${AWS_REGION}"

  aws s3api put-bucket-versioning \
    --bucket "${BUCKET_NAME}" \
    --versioning-configuration Status=Enabled

  aws s3api put-public-access-block \
    --bucket "${BUCKET_NAME}" \
    --public-access-block-configuration \
      BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

  aws s3api put-bucket-encryption \
    --bucket "${BUCKET_NAME}" \
    --server-side-encryption-configuration "{
      \"Rules\":[{\"ApplyServerSideEncryptionByDefault\":{\"SSEAlgorithm\":\"aws:kms\",\"KMSMasterKeyID\":\"${KMS_ALIAS}\"},\"BucketKeyEnabled\":true}]
    }"

  aws s3api put-bucket-policy \
    --bucket "${BUCKET_NAME}" \
    --policy "{
      \"Version\":\"2012-10-17\",
      \"Statement\":[{
        \"Sid\":\"DenyNonTLS\",
        \"Effect\":\"Deny\",
        \"Principal\":\"*\",
        \"Action\":\"s3:*\",
        \"Resource\":[\"arn:aws:s3:::${BUCKET_NAME}\",\"arn:aws:s3:::${BUCKET_NAME}/*\"],
        \"Condition\":{\"Bool\":{\"aws:SecureTransport\":\"false\"}}
      }]
    }"

  echo "[✓] S3 state bucket created and secured: ${BUCKET_NAME}"
fi

# ---- DynamoDB Lock Table ------------------------------------
if aws dynamodb describe-table \
    --table-name "${TABLE_NAME}" \
    --region "${AWS_REGION}" &>/dev/null; then
  echo "[✓] Lock table already exists: ${TABLE_NAME}"
else
  aws dynamodb create-table \
    --table-name "${TABLE_NAME}" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --sse-specification Enabled=true,SSEType=KMS \
    --region "${AWS_REGION}" \
    --tags Key=ManagedBy,Value=bootstrap Key=Environment,Value="${ENV}"

  aws dynamodb wait table-exists \
    --table-name "${TABLE_NAME}" \
    --region "${AWS_REGION}"

  echo "[✓] DynamoDB lock table created: ${TABLE_NAME}"
fi

echo ""
echo "=================================================="
echo " Update examples/${ENV}/backend.tf with:"
echo "   bucket         = \"${BUCKET_NAME}\""
echo "   dynamodb_table = \"${TABLE_NAME}\""
echo "   region         = \"${AWS_REGION}\""
echo "   kms_key_id     = \"${KMS_ALIAS}\""
echo "=================================================="
