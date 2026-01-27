terraform {
  backend "s3" {
    bucket         = "ecs-fargate-lab-tfstate-895930755293"
    key            = "ecs-fargate-lab/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}