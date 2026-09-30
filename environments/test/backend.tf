terraform {
  backend "s3" {
    bucket         = "REPLACE-ME-terraform-state-test"
    key            = "module-library/test/terraform.tfstate"
    region         = "af-south-1"
    encrypt        = true
    use_lockfile = true
  }
}
