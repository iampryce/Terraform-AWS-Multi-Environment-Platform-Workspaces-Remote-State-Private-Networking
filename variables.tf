# ── Core ──────────────────────────────────────────────────────────────────────

variable "region" {
  description = "AWS region to deploy resources into"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.region))
    error_message = "Must be a valid AWS region format, e.g. us-east-1."
  }
}

variable "project_name" {
  description = "Name prefix applied to every resource"
  type        = string

  validation {
    condition     = length(var.project_name) > 0
    error_message = "project_name cannot be empty."
  }
}

variable "owner" {
  description = "Team or person responsible — applied as a tag"
  type        = string
  default     = " "
}

variable "additional_tags" {
  description = "Extra tags to merge into every resource"
  type        = map(string)
  default     = {}
}

# ── Networking ────────────────────────────────────────────────────────────────

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "Must be a valid CIDR block, e.g. 10.0.0.0/16."
  }
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"

  validation {
    condition     = can(cidrnetmask(var.public_subnet_cidr))
    error_message = "Must be a valid CIDR block, e.g. 10.0.1.0/24."
  }
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet"
  type        = string
  default     = "10.0.2.0/24"

  validation {
    condition     = can(cidrnetmask(var.private_subnet_cidr))
    error_message = "Must be a valid CIDR block, e.g. 10.0.2.0/24."
  }
}

# ── Compute ───────────────────────────────────────────────────────────────────

variable "instance_type_map" {
  description = "EC2 instance type per environment"
  type        = map(string)
  default = {
    dev     = "t2.micro"
    staging = "t2.small"
    prod    = "t3.medium"
  }
}

variable "ssh_key_name" {
  description = "EC2 key pair name for SSH. Leave null to use SSM Session Manager"
  type        = string
  default     = null
}

# ── Security ──────────────────────────────────────────────────────────────────

variable "allowed_ssh_cidr" {
  description = "IP range allowed to SSH. Use x.x.x.x/32 in production, never 0.0.0.0/0"
  type        = string
  default     = "0.0.0.0/0"

  validation {
    condition     = can(cidrnetmask(var.allowed_ssh_cidr))
    error_message = "Must be a valid CIDR block."
  }
}
