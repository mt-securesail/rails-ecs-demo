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

variable "budget_alert_email" {
  description = "Where AWS Budgets sends Bedrock spending alerts (infra/ai_review.tf). Set it in terraform.tfvars (gitignored), never in a committed file: this repo is public."
  type        = string
  sensitive   = true # keeps it out of plan and apply output
}

variable "bedrock_monthly_budget_usd" {
  description = "Monthly Amazon Bedrock budget in USD for the spending alerts."
  type        = string
  default     = "5"
}

# The on/off switch (bin/app-power). Off removes only what bills by the hour:
# the load balancer, its listener, and the ECS service (the Fargate task).
# Everything else stays so turning back on takes minutes, not a rebuild.
# bin/app-power sets this in terraform.tfvars, so any later plain
# `terraform apply` keeps the same state instead of flipping it back.
variable "app_enabled" {
  description = "true = the app is running (ALB + Fargate task). false = off, to save cost."
  type        = bool
  default     = true
}

# A load balancer needs at least 2 availability zones. The default VPC has 6,
# and each zone the ALB is in costs a public IPv4 address ($3.65/month).
# The Fargate task uses the same zones, because an ALB only sends traffic to
# targets in its own zones.
variable "app_availability_zones" {
  description = "Availability zones (default-VPC subnets) for the ALB and the Fargate task."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]

  validation {
    condition     = length(var.app_availability_zones) >= 2
    error_message = "An Application Load Balancer needs at least 2 availability zones."
  }
}
