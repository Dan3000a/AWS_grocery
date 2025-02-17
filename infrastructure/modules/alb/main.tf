resource "aws_lb" "grocerymate_alb" {
  name               = "grocerymate-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [module.security_groups.security_group_id]  # ✅ Standardized Security Groups
  subnets            = var.public_subnets  # ✅ Uses Public Subnets

  tags = {
    Name = "GroceryMate-ALB"
  }
}

resource "aws_lb_target_group" "grocerymate_tg" {
  name     = "grocerymate-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "grocerymate_http" {
  load_balancer_arn = aws_lb.grocerymate_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grocerymate_tg.arn
  }
}