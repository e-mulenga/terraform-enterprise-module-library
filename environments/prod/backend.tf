terraform {
  backend "s3" {
    bucket         = "REPLACE-ME-terraform-state-prod"
    key            = "module-library/prod/terraform.tfstate"
    region         = "af-south-1"
    encrypt        = true
    use_lockfile = true
  }
}
