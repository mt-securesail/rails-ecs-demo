# Exception: Trivy flags a public ALB (AWS-0053). It's public by design; access
# is limited to allowed_cidrs by its security group. Decided by Matt,
# 2026-11-10. Revisit in DEPLOYMENT_GUIDE section 21 (opening signups).
#trivy:ignore:AWS-0053
resource "aws_lb" "this" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = data.aws_subnets.default.ids

  # Reject requests with malformed headers (request-smuggling defense; Trivy AWS-0052).
  drop_invalid_header_fields = true
}

resource "aws_lb_target_group" "this" {
  name        = "${var.project_name}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip"

  health_check {
    path                = "/up"
    healthy_threshold   = 2
    unhealthy_threshold = 5
    interval            = 30
    timeout             = 10
  }
}

# Exception: Trivy flags the HTTP (not HTTPS) listener (AWS-0054). HTTPS needs a
# domain and certificate, planned in DEPLOYMENT_GUIDE section 16; until then
# traffic is limited to allowed_cidrs. Decided by Matt, 2026-11-10.
# Revisit (and remove) in section 16.
#trivy:ignore:AWS-0054
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}
