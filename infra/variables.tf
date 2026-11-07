variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short name used to prefix all resources"
  type        = string
  default     = "rails-ecs-demo"
}

variable "github_org" {
  description = "Your GitHub username or org that owns the repo"
  type        = string
}

variable "github_repo" {
  description = "GitHub repo name (without the org prefix)"
  type        = string
}

variable "github_oidc_sub_prefix" {
  description = "Optional. The OIDC subject prefix GitHub puts in tokens for this repo, e.g. repo:owner@123/repo@456. Get it with: gh api repos/OWNER/REPO/actions/oidc/customization/sub. If null, falls back to repo:<github_org>/<github_repo>."
  type        = string
  default     = null
}

variable "allowed_cidrs" {
  description = "IP ranges allowed to reach the load balancer, e.g. [\"203.0.113.7/32\"] for a single address. Use [\"0.0.0.0/0\"] only to open it to the whole internet."
  type        = list(string)

  validation {
    condition     = length(var.allowed_cidrs) > 0
    error_message = "allowed_cidrs must contain at least one CIDR range."
  }
}

variable "container_port" {
  description = "Port the Rails app listens on inside the container"
  type        = number
  default     = 3000
}

variable "secret_key_base" {
  description = "Rails secret_key_base. Generate locally with `bin/rails secret`. Pass with -var, never commit this."
  type        = string
  sensitive   = true
}
