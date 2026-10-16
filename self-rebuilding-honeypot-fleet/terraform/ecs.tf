resource "aws_cloudwatch_log_group" "honeypot" {
  name              = "/honeypot/cowrie"
  retention_in_days = 14
}

resource "aws_ecs_cluster" "honeypot" {
  name = "honeypot-cluster"
}

# Task security group: attackers in on 2222, almost nothing out
resource "aws_security_group" "task" {
  name   = "honeypot-task-sg"
  vpc_id = aws_vpc.honeypot.id
}

resource "aws_vpc_security_group_ingress_rule" "task_from_internet" {
  security_group_id = aws_security_group.task.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 2222
  to_port           = 2222
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "to_endpoints" {
  security_group_id            = aws_security_group.task.id
  referenced_security_group_id = aws_security_group.endpoints.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
}

# Needed so the task can download image layers through the S3 gateway endpoint
resource "aws_vpc_security_group_egress_rule" "to_s3" {
  security_group_id = aws_security_group.task.id
  prefix_list_id    = aws_vpc_endpoint.s3.prefix_list_id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_iam_role" "task_execution" {
  name = "honeypot-task-execution"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_task_definition" "honeypot" {
  family                   = "honeypot-cowrie"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.task_execution.arn

  container_definitions = jsonencode([{
    name         = "cowrie"
    image        = "${aws_ecr_repository.honeypot.repository_url}:latest"
    essential    = true
    portMappings = [{ containerPort = 2222, protocol = "tcp" }]
    environment = [
      { name = "COWRIE_HONEYPOT_HOSTNAME", value = var.honeypot_hostname },
      { name = "COWRIE_SSH_VERSION", value = var.ssh_version }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.honeypot.name
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "cowrie"
      }
    }
  }])
}

resource "aws_ecs_service" "honeypot" {
  name            = "honeypot-service"
  cluster         = aws_ecs_cluster.honeypot.id
  task_definition = aws_ecs_task_definition.honeypot.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.private.id]
    security_groups  = [aws_security_group.task.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.honeypot.arn
    container_name   = "cowrie"
    container_port   = 2222
  }

  depends_on = [
    aws_lb_listener.ssh,
    aws_vpc_endpoint.ecr_api,
    aws_vpc_endpoint.ecr_dkr,
    aws_vpc_endpoint.logs,
    aws_vpc_endpoint.s3
  ]
}
