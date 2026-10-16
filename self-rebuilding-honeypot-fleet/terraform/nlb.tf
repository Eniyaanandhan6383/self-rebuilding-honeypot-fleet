resource "aws_lb" "honeypot" {
  name               = "honeypot-nlb"
  load_balancer_type = "network"
  subnets            = [aws_subnet.public.id]
}

resource "aws_lb_target_group" "honeypot" {
  name        = "honeypot-tg"
  port        = 2222
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = aws_vpc.honeypot.id

  # Keep the real attacker IP in the logs - verify this behaves as expected
  preserve_client_ip = "true"
}

resource "aws_lb_listener" "ssh" {
  load_balancer_arn = aws_lb.honeypot.arn
  port              = 22
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.honeypot.arn
  }
}
