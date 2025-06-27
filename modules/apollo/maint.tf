# EC2
resource "aws_instance" "this" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  key_name               = var.key_pair_name
  vpc_security_group_ids = [var.security_group_id]

  user_data = var.user_data

  tags = {
    Name = "apollo-server"
  }
}
