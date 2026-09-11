terraform {
  backend "s3" {
    bucket         = "REPLACE-ME-terraform-state-prod"
    key            = "module-library/prod/terraform.tfstate"
    region         = "af-south-1"
    encrypt        = true
    kms_key_id     = "alias/terraform-state-key-prod"
    dynamodb_table = "REPLACE-ME-terraform-state-lock-prod"
  }
}
