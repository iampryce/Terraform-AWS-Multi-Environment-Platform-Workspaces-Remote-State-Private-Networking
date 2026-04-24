# S3 bucket must exist before running terraform init
terraform {
  backend "s3" {
    bucket = "multi-env-platform-terraform-state"
    region = "us-east-1" 

    # Workspace injects itself: env:/dev/terraform/terraform.tfstate
    key = "terraform/terraform.tfstate"

    use_lockfile = true      # prevents concurrent applies from corrupting state
  }
}


