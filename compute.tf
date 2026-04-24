resource "aws_instance" "app" {
  ami           = var.ami_id
  instance_type = local.instance_type   # driven by workspace: dev=t2.micro, prod=t3.medium

  subnet_id              = aws_subnet.private.id   # private — no direct internet exposure
  vpc_security_group_ids = [aws_security_group.ec2.id]

  # No key pair defined here — access via AWS SSM Session Manager is the modern approach
  # Add key_name = "your-key" if you need traditional SSH

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-app-server"
  })
}
