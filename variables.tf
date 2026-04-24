# ─── Core ────────────────────────────────────────────────────────────────────

variable "region" {
  description = "AWS region to deploy resources into"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.region))
    error_message = "Region must be a valid AWS region format, e.g. us-east-1."
  }
}

variable "project_name" {
  description = "Name prefix applied to every resource for identification"
  type        = string

  validation {
    condition     = length(var.project_name) > 0
    error_message = "project_name cannot be empty."
  }
}

# ─── Networking ───────────────────────────────────────────────────────────────

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet"
  type        = string
  default     = "10.0.2.0/24"
}

# ─── Compute ──────────────────────────────────────────────────────────────────

variable "instance_type_map" {
  description = "EC2 instance type per workspace environment"
  type        = map(string)
  default = {
    dev     = "t2.micro"
    staging = "t2.small"
    prod    = "t3.medium"
  }
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance (Amazon Linux 2 in us-east-1 by default)"
  type        = string
  default     = "ami-0c02fb55956c7d316"
}

# ─── Security ─────────────────────────────────────────────────────────────────

variable "allowed_ssh_cidr" {
  description = "CIDR allowed to SSH into instances. Use your IP: x.x.x.x/32"
  type        = string
  default     = "0.0.0.0/0"

  validation {
    condition     = can(cidrnetmask(var.allowed_ssh_cidr))
    error_message = "allowed_ssh_cidr must be a valid CIDR block."
  }
}
