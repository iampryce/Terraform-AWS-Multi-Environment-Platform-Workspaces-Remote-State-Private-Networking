region       = "us-east-1"
project_name = "multi-env-platform"

# Networking
vpc_cidr            = "10.0.0.0/16"
public_subnet_cidr  = "10.0.1.0/24"
private_subnet_cidr = "10.0.2.0/24"

# Compute — instance_type_map lives in variables.tf defaults
# Override here if you need non-default sizes
# instance_type_map = {
#   dev     = "t2.nano"
#   staging = "t2.small"
#   prod    = "t3.large"
# }

# Security — replace with your actual IP for real use: "x.x.x.x/32"
allowed_ssh_cidr = "0.0.0.0/0"
