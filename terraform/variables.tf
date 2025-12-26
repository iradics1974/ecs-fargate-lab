variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "eu-central-1"
}

variable "app_name" {
  description = "Name of the application (used for ECS, ALB, etc.)"
  type        = string
  default     = "ecs-fargate-lab"
}

variable "container_port" {
  description = "Port the application listens on"
  type        = number
  default     = 8080
}

variable "ecr_image_uri" {
  description = "Full ECR image URI with tag"
  type        = string
}
