terraform {
  backend "s3" {
    bucket = "multi-env-platform-terraform-state"
    # terraform.workspace is injected automatically into the key path
    # Result: terraform/dev/terraform.tfstate
    #         terraform/prod/terraform.tfstate
    key    = "terraform/terraform.tfstate"
    region = "us-east-1"

    # Native S3 lock file — prevents two applies running at the same time
    use_lockfile = true
  }
}
