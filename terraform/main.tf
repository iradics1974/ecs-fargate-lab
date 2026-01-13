########################################
# Providers & basics
########################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

########################################
# Data sources
########################################

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

########################################
# CloudWatch Logs
########################################

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/ecs-fargate-lab"
  retention_in_days = 7
}

########################################
# Security Groups
########################################

# App / ECS
resource "aws_security_group" "app_sg" {
  name   = "ecs-fargate-lab-app-sg"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# DB
resource "aws_security_group" "db_sg" {
  name   = "ecs-fargate-lab-db-sg"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

########################################
# ECS Cluster
########################################

resource "aws_ecs_cluster" "this" {
  name = "ecs-fargate-lab"
}

########################################
# IAM – ECS task execution role
########################################

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-fargate-lab-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_base" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

########################################
# Secrets Manager – DB credentials
########################################

resource "random_password" "db" {
  length           = 20
  special          = true
  override_special = "!@#%^*-_+="
}

resource "aws_secretsmanager_secret" "db" {
  name                    = "ecs-fargate-lab/db"
  description             = "DB credentials for ecs-fargate-lab"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id

  secret_string = jsonencode({
    username = "appuser"
    password = random_password.db.result
  })
}

resource "aws_iam_role_policy" "ecs_secrets_access" {
  name = "ecs-secrets-access"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = aws_secretsmanager_secret.db.arn
    }]
  })
}

########################################
# RDS – Postgres (DEV)
########################################

resource "aws_db_subnet_group" "db" {
  name       = "ecs-fargate-lab-db-subnet-group"
  subnet_ids = data.aws_subnets.default.ids
}

locals {
  db_credentials = jsondecode(
    aws_secretsmanager_secret_version.db.secret_string
  )
}

resource "aws_db_instance" "db" {
  identifier = "ecs-fargate-lab-dev-db"

  engine         = "postgres"
  engine_version = "15"
  instance_class = "db.t4g.micro"

  allocated_storage = 20
  storage_type      = "gp3"

  db_name  = "app"
  username = local.db_credentials.username
  password = local.db_credentials.password

  db_subnet_group_name   = aws_db_subnet_group.db.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]

  publicly_accessible     = false
  skip_final_snapshot     = true
  deletion_protection     = false
  backup_retention_period = 0
}

########################################
# ECS Task Definition
########################################

resource "aws_ecs_task_definition" "this" {
  family                   = "ecs-fargate-lab"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "ecs-fargate-lab"
      image     = var.ecr_image_uri
      essential = true

      portMappings = [{
        containerPort = 8080
        protocol      = "tcp"
      }]

      environment = [
        { name = "DB_HOST", value = aws_db_instance.db.address },
        { name = "DB_NAME", value = "app" },
        { name = "DB_USER", value = "appuser" }
      ]

      secrets = [
        {
          name      = "DB_PASSWORD"
          valueFrom = aws_secretsmanager_secret.db.arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

########################################
# Load Balancer
########################################

resource "aws_lb" "this" {
  name               = "ecs-fargate-lab-alb"
  load_balancer_type = "application"
  subnets            = data.aws_subnets.default.ids
  security_groups    = [aws_security_group.app_sg.id]
}

resource "aws_lb_target_group" "this" {
  name        = "ecs-fargate-lab-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip"

  health_check {
    path = "/"
  }
}

resource "aws_lb_listener" "this" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

########################################
# ECS Service
########################################

resource "aws_ecs_service" "this" {
  name            = "ecs-fargate-lab"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.app_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = "ecs-fargate-lab"
    container_port   = 8080
  }

  depends_on = [
    aws_lb_listener.this,
    aws_cloudwatch_log_group.ecs
  ]
}
