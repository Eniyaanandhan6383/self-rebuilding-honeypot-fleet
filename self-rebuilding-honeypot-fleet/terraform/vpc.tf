data "aws_availability_zones" "az" {
  state = "available"
}

resource "aws_vpc" "honeypot" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "honeypot-vpc" }
}

# Public subnet: only the NLB lives here
resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.honeypot.id
  cidr_block        = "10.20.0.0/24"
  availability_zone = data.aws_availability_zones.az.names[0]
  tags              = { Name = "honeypot-public" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.honeypot.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.honeypot.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Private subnet: honeypot tasks. NO NAT, NO internet route.
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.honeypot.id
  cidr_block        = "10.20.1.0/24"
  availability_zone = data.aws_availability_zones.az.names[0]
  tags              = { Name = "honeypot-private" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.honeypot.id
  tags   = { Name = "honeypot-private-no-internet" }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# ---- VPC endpoints so Fargate can pull the image and write logs without internet ----
resource "aws_security_group" "endpoints" {
  name   = "honeypot-endpoints-sg"
  vpc_id = aws_vpc.honeypot.id
}

resource "aws_vpc_security_group_ingress_rule" "endpoints_from_task" {
  security_group_id            = aws_security_group.endpoints.id
  referenced_security_group_id = aws_security_group.task.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
}

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.honeypot.id
  service_name        = "com.amazonaws.${var.region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private.id]
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.honeypot.id
  service_name        = "com.amazonaws.${var.region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private.id]
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "logs" {
  vpc_id              = aws_vpc.honeypot.id
  service_name        = "com.amazonaws.${var.region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private.id]
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true
}

# S3 gateway endpoint: ECR stores image layers in S3
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.honeypot.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]
}
