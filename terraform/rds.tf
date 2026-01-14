########################################
# DB Subnet Group (private subnets)
########################################

resource "aws_db_subnet_group" "this" {
  name       = "ecs-fargate-lab-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "ecs-fargate-lab-db-subnet-group"
  }
}

########################################
# RDS PostgreSQL Instance
########################################

resource "aws_db_instance" "this" {
  identifier = "ecs-fargate-lab-postgres"

  engine         = "postgres"
  engine_version = "15.4"

  instance_class    = "db.t3.micro"
  allocated_storage = 20

  db_name  = "appdb"
  username = "appuser"
  password = aws_secretsmanager_secret_version.db_password.secret_string

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  publicly_accessible = false
  skip_final_snapshot = true
  deletion_protection = false

  backup_retention_period = 0

  tags = {
    Name = "ecs-fargate-lab-postgres"
  }
}
