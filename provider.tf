terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # 5.x only, never auto-upgrade to 6
    }
  }
}

provider "aws" {
  region = var.region
}
