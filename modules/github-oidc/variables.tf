variable "github_repository" {
  description = "GitHub repository in owner/repository format"
  type        = string
}

variable "environment" {
  description = "GitHub environment"
  type        = string
}

variable "role_name" {
  description = "OIDC deployment role name"
  type        = string
}
