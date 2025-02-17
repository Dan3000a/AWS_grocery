resource "aws_db_instance" "grocery_db" {
  allocated_storage     = 20
  engine               = "postgres"
  engine_version       = "14.6"  # ✅ LTS-stable version
  instance_class       = "db.t3.micro"
  db_name              = "grocerymate"
  username            = var.db_username
  password            = var.db_password
  db_subnet_group_name = aws_db_subnet_group.grocery_db_subnet.name
  vpc_security_group_ids = [module.security_groups.security_group_id]
  publicly_accessible   = false
  skip_final_snapshot   = true

  tags = {
    Name      = "GroceryMate-DB"
    DBVersion = "14.6"  # ✅ Informational tag
  }
}

resource "aws_db_subnet_group" "grocery_db_subnet" {
  name       = "grocery-db-subnet-group"
  subnet_ids = var.private_subnets  # ✅ Uses private subnets dynamically

  tags = {
    Name = "GroceryMate RDS Subnet Group"
  }
}