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
  type    = string
  default = "895930755293.dkr.ecr.eu-central-1.amazonaws.com/ecs-fargate-lab-app:124"
}

variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "PostgreSQL master username"
  type        = string
  default     = "appuser"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage (GB)"
  type        = number
  default     = 20
}
