terraform {
  backend "s3" {
    bucket         = "REPLACE-ME-terraform-state-test"
    key            = "module-library/test/terraform.tfstate"
    region         = "af-south-1"
    encrypt        = true
    kms_key_id     = "alias/terraform-state-key-test"
    dynamodb_table = "REPLACE-ME-terraform-state-lock-test"
  }
}
