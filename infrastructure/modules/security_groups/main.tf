# Data source to get your public IP dynamically
data "external" "my_ip" {
  program = ["bash", "-c", "echo '{\"ip\": \"'$(curl -s https://checkip.amazonaws.com)'\"}'"]
}

# Security Group for Web Instances (Target Instances)
resource "aws_security_group" "web_sg" {
  name        = var.security_group_name
  description = "Allow inbound HTTP, HTTPS, SSH, and DB traffic"
  vpc_id      = var.vpc_id

  # Allow HTTP access from ALB
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
    description     = "Allow HTTP from ALB"
  }

  # Allow HTTPS access from ALB
  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
    description     = "Allow HTTPS from ALB"
  }

  # Allow SSH access from your IP
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_cidr
    description = "Allow SSH from specified IP"
  }

  # Allow SSH access from Bastion Security Group
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
    description     = "Allow SSH from Bastion Host"
  }

  # Allow EC2 to communicate with RDS on port 5432 (from VPC CIDR)
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = var.private_cidr
    description = "Allow RDS access from VPC CIDR"
  }

  # Allow RDS access from Bastion
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
    description     = "Allow RDS access from Bastion"
  }

  # Allow Gunicorn traffic from ALB
  ingress {
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
    description     = "Allow Gunicorn traffic from ALB"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "Web Security Group"
  }
}

# Security Group for Bastion
resource "aws_security_group" "bastion_sg" {
  name        = "bastion-sg"
  description = "Security group for the Bastion Host"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.manual_ip == "auto" ? [format("%s/32", data.external.my_ip.result.ip)] : [var.manual_ip]
    description = "Allow SSH from specified IP"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "BastionHostSG"
  }
}