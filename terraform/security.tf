########################################
# ALB Security Group
########################################

resource "aws_security_group" "alb" {
  name        = "ecs-fargate-lab-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # (HTTPS később jön, certtel együtt)
  # ingress {
  #   from_port   = 443
  #   to_port     = 443
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ecs-fargate-lab-alb-sg"
  }
}

########################################
# ECS Service Security Group
########################################

resource "aws_security_group" "ecs" {
  name        = "ecs-fargate-lab-ecs-sg"
  description = "Security group for ECS tasks"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "Traffic from ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ecs-fargate-lab-ecs-sg"
  }
}

########################################
# RDS Security Group
########################################

resource "aws_security_group" "rds" {
  name        = "ecs-fargate-lab-rds-sg"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "Postgres from ECS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ecs-fargate-lab-rds-sg"
  }
}
