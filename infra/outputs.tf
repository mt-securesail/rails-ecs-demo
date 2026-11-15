# null while the app is switched off.
output "alb_dns_name" {
  value = one(aws_lb.this[*].dns_name)
}

output "app_url" {
  value = var.app_enabled ? "http://${aws_lb.this[0].dns_name}" : null
}

output "ecr_repository_url" {
  value = aws_ecr_repository.this.repository_url
}

output "github_deploy_role_arn" {
  value = aws_iam_role.github_deploy.arn
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "ecs_service_name" {
  value = local.ecs_service_name
}

output "ecs_task_family" {
  value = aws_ecs_task_definition.this.family
}
