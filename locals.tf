locals {
  env           = terraform.workspace # active environment: dev / staging / prod
  instance_type = lookup(var.instance_type_map, local.env, "t2.micro")
  name_prefix   = "${var.project_name}-${local.env}"

  common_tags = merge(
    {
      Project     = var.project_name
      Environment = local.env
      ManagedBy   = "terraform"
      Owner       = var.owner
    },
    var.additional_tags # any extra tags passed in via tfvars
  )
}
