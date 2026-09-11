terraform {
  backend "s3" {
    bucket         = "REPLACE-ME-terraform-state-dev"
    key            = "module-library/dev/terraform.tfstate"
    region         = "af-south-1"
    encrypt        = true
    kms_key_id     = "alias/terraform-state-key-dev"
    dynamodb_table = "REPLACE-ME-terraform-state-lock-dev"
  }
}
