resource "aws_iam_role" "main" {
  name_prefix = "load"

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
  ]

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_instance_profile" "main" {
  name_prefix = "load"
  role = "${aws_iam_role.main.name}"
}

resource "aws_security_group" "main" {
  name_prefix = "load"
  vpc_id      = var.vpc_id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "client_allout" {
  type              = "egress"
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  to_port           = 0
  security_group_id = aws_security_group.main.id
}

resource "aws_launch_template" "main" {
  name_prefix   = "load"
  image_id      = var.ami
  instance_type = "t2.micro"

  vpc_security_group_ids = [
    aws_security_group.main.id,
  ]

  iam_instance_profile {
    arn = aws_iam_instance_profile.main.arn
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh.tpl", { endpoint = var.endpoint }))
}

resource "aws_autoscaling_group" "main" {
  desired_capacity   = 4
  max_size           = 5
  min_size           = 1

  vpc_zone_identifier = var.private_subnets

  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "load-${var.name}"
    propagate_at_launch = true
  }
}
