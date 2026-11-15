locals {
  # Fixed here so the deploy role's policy (infra/iam.tf) can name the service
  # even while it's switched off.
  ecs_service_name = "${var.project_name}-service"
}

data "aws_caller_identity" "current" {}

resource "aws_ecs_cluster" "this" {
  name = "${var.project_name}-cluster"
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 14
}

# The container image tag below is a placeholder. The first run of the
# GitHub Actions CD workflow will register a new task definition revision
# pointing at a real image and update the service to use it.
resource "aws_ecs_task_definition" "this" {
  family                   = "${var.project_name}-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = "${aws_ecr_repository.this.repository_url}:placeholder"
      essential = true
      portMappings = [{
        containerPort = var.container_port
        protocol      = "tcp"
      }]
      secrets = [
        {
          name      = "SECRET_KEY_BASE"
          valueFrom = aws_ssm_parameter.secret_key_base.arn
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.this.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "app"
        }
      }
    }
  ])

  lifecycle {
    ignore_changes = [container_definitions]
  }
}

resource "aws_ecs_service" "this" {
  count = var.app_enabled ? 1 : 0 # the on/off switch (bin/app-power)

  name    = local.ecs_service_name
  cluster = aws_ecs_cluster.this.id
  # The family name without a revision means "the latest active revision": the
  # one the last CD run registered, with a real image. (Terraform's own
  # revision has the placeholder image.) So turning the app back on runs the
  # latest deployed code, with no rebuild.
  task_definition = aws_ecs_task_definition.this.family
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.app.ids
    security_groups  = [aws_security_group.service.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = "app"
    container_port   = var.container_port
  }

  depends_on = [aws_lb_listener.http]

  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }
}

# Keep the existing service when count was added (no rebuild).
moved {
  from = aws_ecs_service.this
  to   = aws_ecs_service.this[0]
}
