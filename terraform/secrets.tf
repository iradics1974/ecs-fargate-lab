########################################
# Random DB password
########################################

resource "random_password" "db" {
  length  = 24
  special = true
}

########################################
# Secrets Manager - DB password
########################################

resource "aws_secretsmanager_secret" "db_password" {
  name        = "ecs-fargate-lab-db-password"
  description = "PostgreSQL password for ECS Fargate lab"

  tags = {
    Name = "ecs-fargate-lab-db-password"
  }
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db.result
}
