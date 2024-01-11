locals {
  prefix = var.prefix
}

data "aws_caller_identity" "current" {}

resource "aws_lb" "nlb" {
  load_balancer_type = "network"

  name_prefix = "${local.prefix}-nlb"
  internal    = true
  subnets     = var.public_subnets

  access_logs {
    bucket  = var.access_logs_bucket
    enabled = true
  }
}

resource "aws_security_group" "load_balancer" {
  name_prefix = local.prefix
  description = "ALB Security Group"
  vpc_id      = var.vpc_id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "load_balancer_allout" {
  type              = "egress"
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  to_port           = 0
  security_group_id = aws_security_group.load_balancer.id
}

resource "aws_security_group_rule" "load_balancer_in" {
  type              = "ingress"
  protocol          = "tcp"
  cidr_blocks       = var.cidr_blocks
  from_port         = 80
  to_port           = 80
  security_group_id = aws_security_group.load_balancer.id
}

resource "aws_alb" "public" {
  name_prefix        = "${local.prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = var.public_subnets

  drop_invalid_header_fields = true

  security_groups = [aws_security_group.load_balancer.id]

  access_logs {
    bucket  = var.access_logs_bucket
    enabled = true
  }
}

resource "aws_alb_listener" "http" {
  load_balancer_arn = aws_alb.public.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Fixed response content"
      status_code  = "200"
    }
  }
}

resource "aws_lb_listener" "nlb" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nlb_to_alb.arn
  }
}

resource "aws_lb_target_group" "nlb_to_alb" {
  name_prefix = "${local.prefix}-nlb"
  port        = 80
  protocol    = "TCP"
  target_type = "alb"
  vpc_id      = var.vpc_id

  health_check {
    protocol = "HTTP"
  }
}

resource "aws_lb_target_group_attachment" "alb" {
  target_group_arn = aws_lb_target_group.nlb_to_alb.arn
  target_id        = aws_alb.public.arn
  port             = 80
}

resource "aws_vpc_endpoint_service" "nlb" {
  acceptance_required        = false
  allowed_principals         = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
  network_load_balancer_arns = [aws_lb.nlb.arn]

  tags = {
    Name = local.prefix
  }
}
