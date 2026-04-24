resource "aws_instance" "app" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = local.instance_type # dev=t2.micro, staging=t2.small, prod=t3.medium

  subnet_id              = aws_subnet.private.id # private subnet — no public IP
  vpc_security_group_ids = [aws_security_group.ec2.id]

  key_name = var.ssh_key_name # null = SSM access only

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-app-server"
  })
}
