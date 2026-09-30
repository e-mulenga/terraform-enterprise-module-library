terraform {
  backend "s3" {
    bucket         = "REPLACE-ME-terraform-state-dev"
    key            = "module-library/dev/terraform.tfstate"
    region         = "af-south-1"
    encrypt        = true
    use_lockfile = true
  }
}
