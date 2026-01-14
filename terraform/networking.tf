########################################
# VPC
########################################

resource "aws_vpc" "this" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "ecs-fargate-lab-vpc"
  }
}

########################################
# Availability Zones
########################################

data "aws_availability_zones" "available" {
  state = "available"
}

########################################
# Internet Gateway
########################################

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "ecs-fargate-lab-igw"
  }
}

########################################
# Public Subnets (ALB)
########################################

resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet("10.0.0.0/16", 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "ecs-fargate-lab-public-${count.index + 1}"
  }
}

########################################
# Private Subnets (ECS + RDS)
########################################

resource "aws_subnet" "private" {
  count = 2

  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet("10.0.0.0/16", 8, count.index + 10)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "ecs-fargate-lab-private-${count.index + 1}"
  }
}

########################################
# Elastic IP for NAT Gateway
########################################

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "ecs-fargate-lab-nat-eip"
  }
}

########################################
# NAT Gateway (single, cost-conscious)
########################################

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "ecs-fargate-lab-nat"
  }

  depends_on = [aws_internet_gateway.this]
}

########################################
# Route Tables
########################################

# Public route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "ecs-fargate-lab-public-rt"
  }
}

# Private route table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }

  tags = {
    Name = "ecs-fargate-lab-private-rt"
  }
}

########################################
# Route Table Associations
########################################

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
