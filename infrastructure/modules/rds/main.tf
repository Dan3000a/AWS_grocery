resource "aws_db_instance" "grocery_db" {
  allocated_storage    = 20
  engine              = "postgres"
  engine_version      = "13.3"
  instance_class      = "db.t3.micro"
  username           = var.db_username
  password           = var.db_password
  db_subnet_group_name = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  publicly_accessible  = false
  skip_final_snapshot  = true

  tags = {
    Name = "GroceryMate-DB"
  }
}

resource "aws_db_subnet_group" "main" {
  name       = "grocery-db-subnet-group"
  subnet_ids = var.private_subnets

  tags = {
    Name = "GroceryMate RDS Subnet Group"
  }
}