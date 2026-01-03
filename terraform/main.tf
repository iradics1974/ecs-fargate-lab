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
# Vault – DB secret
########################################

data "vault_kv_secret_v2" "db" {
  mount = "secret"
  name  = "app/db"
}

########################################
# Security Group (MEGLÉVŐHÖZ IGAZÍTVA)
########################################

resource "aws_security_group" "app_sg" {
  name        = "ecs-fargate-lab-sg"
  description = "Allow HTTP traffic to ECS Fargate app"
  vpc_id      = data.aws_vpc.default.id

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

########################################
# ECS Cluster (NÉV VISSZAIGAZÍTVA)
########################################

resource "aws_ecs_cluster" "this" {
  name = "ecs-fargate-lab"
}

########################################
# IAM – ECS task execution role (NÉV FIX)
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

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

########################################
# RDS – subnet group + DB security group
########################################

resource "aws_db_subnet_group" "db" {
  name       = "ecs-fargate-lab-db-subnet-group"
  subnet_ids = data.aws_subnets.default.ids
}

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
# RDS – Postgres (ÚJ RESOURCE)
########################################

resource "aws_db_instance" "db" {
  identifier = "ecs-fargate-lab-dev-db"

  engine         = "postgres"
  engine_version = "15"
  instance_class = "db.t4g.micro"

  allocated_storage = 20
  storage_type      = "gp3"

  db_name  = "app"
  username = "appuser"
  password = data.vault_kv_secret_v2.db.data["password"]

  db_subnet_group_name   = aws_db_subnet_group.db.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]

  publicly_accessible      = false
  skip_final_snapshot      = true
  deletion_protection      = false
  backup_retention_period  = 0
}

########################################
# ECS Task Definition (IMAGE FIXÁLT)
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
        { name = "DB_HOST",      value = aws_db_instance.db.address },
        { name = "DB_NAME",      value = "app" },
        { name = "DB_USER",      value = "appuser" },
        { name = "DB_PASSWORD",  value = data.vault_kv_secret_v2.db.data["password"] }
      ]
    }
  ])
}

########################################
# Load Balancer (MEGLÉVŐ)
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
# ECS Service (NÉV FIX)
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

  depends_on = [aws_lb_listener.this]
}
