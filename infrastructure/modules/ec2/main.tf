resource "aws_instance" "web_server" {
  ami                  = var.ami
  instance_type        = var.instance_type
  key_name             = var.key_pair_name
  security_groups      = [aws_security_group.web_sg.name]
  associate_public_ip_address = false  # EC2 is in a private subnet

  tags = {
    Name = var.instance_name
  }

  # Install Apache & Allow Web Access
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "Hello, World!" > /var/www/html/index.html
              EOF
}