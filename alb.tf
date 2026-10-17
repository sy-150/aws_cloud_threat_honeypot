# Creating a Security Group with separated rules
resource "aws_security_group" "alb_sg" {
  name        = "project_alb_sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.vpc1.id
}

# Defining the ALB ingress rule to receive internet requests via TCP and port 80
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

# Defining the ALB ingress rule to receive internet requests via TCP and port 443
resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

# Defining the ALB Egress rule to respond to requests from the internet
resource "aws_vpc_security_group_egress_rule" "name" {
  security_group_id = aws_security_group.alb_sg.id
  cidr_ipv4 = "0.0.0.0/0"
  ip_protocol = "-1"
}

# Creating the Application Load Balancer
# Uses the previously defined security groups and public subnets
resource "aws_lb" "project-lb" {
  name               = "project"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.subnets_public[*].id
}

# Creating the Application Load Balancer Target Group
# Uses port 80 and round robin mechanism to balance load between instances
resource "aws_lb_target_group" "alb-tg" {
  name                          = "project-alb-tg"
  port                          = 80
  protocol                      = "HTTP"
  load_balancing_algorithm_type = "round_robin"
  vpc_id                        = aws_vpc.vpc1.id
  target_type                   = "instance" #Default

  health_check {
    enabled             = true
    path                = "/"
    port                = 80
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }
}

# Creating the ALB listener for HTTPS requests
# Uses the ARN of the previously created and validated ACM Certificate
# Uses ssl_policy for security
resource "aws_lb_listener" "lb" {
  load_balancer_arn = aws_lb.project-lb.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate_validation.project_cert_validation.certificate_arn
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"

  # Forwards the request to the target group
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb-tg.arn
  }
}

# Creating a listener for HTTP requests
resource "aws_lb_listener" "lb_listener_HTTP" {
  load_balancer_arn = aws_lb.project-lb.arn
  port              = 80
  protocol          = "HTTP"

  # Redirects HTTP requests to port 443
  default_action {
    type = "redirect"
    redirect {
      port        = 443
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}