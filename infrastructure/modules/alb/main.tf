# Define the Application Load Balancer
resource "aws_lb" "grocerymate_alb" {
  name               = "grocerymate-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnets
  tags = {
    Name = "GroceryMate-ALB"
  }
}

# Define the Target Group for forwarding traffic
resource "aws_lb_target_group" "grocerymate_tg" {
  name     = "grocerymate-target-group-v2"  # Changed to a unique name
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  health_check {
    path                = "/api/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Define the Listener for HTTP traffic
resource "aws_lb_listener" "grocerymate_http" {
  load_balancer_arn = aws_lb.grocerymate_alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grocerymate_tg.arn
  }
  depends_on = [aws_lb_target_group.grocerymate_tg]
  lifecycle {
    create_before_destroy = true
  }
}