# Uses the account's default VPC/subnets to keep this demo simple.
# A real production setup would use a purpose-built VPC with private subnets + NAT.

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Allow inbound HTTP to the ALB"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  # The ALB only needs to reach the app containers (and health-check them) on
  # the container port inside this VPC. (Pointing at the service security
  # group instead would create a circular reference between the two groups.)
  egress {
    description = "To app containers in this VPC"
    from_port   = var.container_port
    to_port     = var.container_port
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
  }
}

resource "aws_security_group" "service" {
  name        = "${var.project_name}-service-sg"
  description = "Allow inbound traffic from the ALB only"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Outbound HTTPS only. The task needs it to pull its image (ECR), send logs
  # (CloudWatch), and read SECRET_KEY_BASE (SSM); later, for outside APIs.
  # Exception: Trivy flags any 0.0.0.0/0 egress (AWS-0104). Removing it needs
  # VPC endpoints (~$7+/month each), declined for now to avoid cost.
  # Decided by the repo owner (mt-securesail), 2026-11-10. Review by 2027-01-31.
  #trivy:ignore:AWS-0104:exp:2027-01-31
  egress {
    description = "Outbound HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
