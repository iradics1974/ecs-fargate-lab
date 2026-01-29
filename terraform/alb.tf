########################################
# Application Load Balancer
########################################

resource "aws_lb" "this" {
  name               = "ecs-fargate-lab-alb"
  load_balancer_type = "application"
  internal           = false

  subnets         = aws_subnet.public[*].id
  security_groups = [aws_security_group.alb.id]

  tags = {
    Name = "ecs-fargate-lab-alb"
  }
}

########################################
# Target Group (for ECS Service later)
########################################

resource "aws_lb_target_group" "this" {
  name        = "ecs-fargate-lab-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.this.id
  target_type = "ip"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "ecs-fargate-lab-tg"
  }
}

########################################
# Listener (HTTP :80)
########################################

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}
