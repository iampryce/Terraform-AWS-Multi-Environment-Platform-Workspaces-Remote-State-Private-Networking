locals {
  # Which workspace is active right now: dev / staging / prod
  env = terraform.workspace

  # Instance type driven by environment — no hardcoding anywhere
  instance_type = lookup(var.instance_type_map, local.env, "t2.micro")

  # Consistent naming prefix used by every resource
  name_prefix = "${var.project_name}-${local.env}"

  common_tags = {
    Project     = var.project_name
    Environment = local.env
    ManagedBy   = "terraform"
  }
}
