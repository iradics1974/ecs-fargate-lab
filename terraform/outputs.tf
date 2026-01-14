########################################
# Load Balancer
########################################

output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer"
  value       = aws_lb.this.dns_name
}

########################################
# ECS
########################################

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.this.name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.this.name
}

########################################
# RDS
########################################

output "db_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = aws_db_instance.this.address
}

output "db_name" {
  description = "Database name"
  value       = aws_db_instance.this.db_name
}

########################################
# Networking (opcionális, de demo-barát)
########################################

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.this.id
}
