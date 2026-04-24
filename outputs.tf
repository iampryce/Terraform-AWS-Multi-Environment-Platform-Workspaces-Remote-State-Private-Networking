output "environment" {
  description = "Active Terraform workspace"
  value       = local.env
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.public.id
}

output "private_subnet_id" {
  description = "ID of the private subnet"
  value       = aws_subnet.private.id
}

# Use with SSM: aws ssm start-session --target <value>
output "ec2_instance_id" {
  description = "ID of the app EC2 instance"
  value       = aws_instance.app.id
}

output "ec2_private_ip" {
  description = "Private IP of the app EC2 instance"
  value       = aws_instance.app.private_ip
}

# Whitelist this IP in any external firewall or third-party API
output "nat_gateway_public_ip" {
  description = "Outbound public IP used by all private instances"
  value       = aws_eip.nat.public_ip
}
