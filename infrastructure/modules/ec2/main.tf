resource "aws_instance" "web_server" {
  ami           = var.ami
  instance_type = var.instance_type
  key_name      = var.key_pair_name
  subnet_id     = element(var.private_subnets, 0)   # ✅ Picks first private subnet

  vpc_security_group_ids = [module.security_groups.security_group_id]  # ✅ Consistency across modules

  tags = {
    Name = var.instance_name
  }
}