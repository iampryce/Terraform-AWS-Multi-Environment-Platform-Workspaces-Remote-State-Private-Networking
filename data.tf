# Resolves the latest Amazon Linux 2 AMI at plan time — no hardcoded IDs
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"] # official Amazon images only

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
