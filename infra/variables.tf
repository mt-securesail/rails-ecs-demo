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
