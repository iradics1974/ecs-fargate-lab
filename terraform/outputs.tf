output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer"
  value       = aws_lb.this.dns_name
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.this.name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.this.name
}
