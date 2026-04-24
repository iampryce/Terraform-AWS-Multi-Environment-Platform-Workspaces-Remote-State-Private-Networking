# Terraform Multi-Environment Workspaces

> Designed and implemented a production-style AWS infrastructure using Terraform with environment isolation, secure networking, and scalable configuration.

---

## Project Summary

This project demonstrates how to design and deploy a multi-environment AWS infrastructure using Terraform.

It uses Terraform Workspaces to manage dev, staging, and production environments from a single codebase, with remote state stored in S3 and native state locking enabled.

The architecture follows production best practices:
- Private EC2 instances with no direct internet exposure
- Controlled internet access via NAT Gateway
- Environment-based instance sizing using locals and workspace detection
- Fully parameterized infrastructure using variables and validation

---

## Key Skills Demonstrated

- Terraform (Infrastructure as Code)
- AWS Networking (VPC, Subnets, IGW, NAT Gateway, Route Tables)
- Multi-environment design using Terraform Workspaces
- Remote state management (S3 backend with native lockfile)
- Environment-based configuration using variables and locals
- Secure infrastructure design (private subnets, restricted SSH, security groups)

---

## Architecture Overview

```
Internet
   │
   ▼
Internet Gateway
   │
   ▼
Public Subnet (10.0.1.0/24)
   │         │
   │         ▼
   │     NAT Gateway ──── Elastic IP
   │
   ▼
Private Subnet (10.0.2.0/24)
   │
   ▼
EC2 Instance (app server)
   │
Security Group (virtual firewall)
```

**Traffic flow:**
- Public subnet resources can reach the internet directly through the IGW
- Private EC2 instances send outbound traffic through NAT (updates, installs)
- No inbound traffic can reach the private subnet from the internet
- SSH is restricted to a configurable CIDR (`allowed_ssh_cidr`)

---

## Environment Differences

| Resource       | dev        | staging    | prod        |
|----------------|------------|------------|-------------|
| EC2 instance   | t2.micro   | t2.small   | t3.medium   |
| Resource names | `*-dev-*`  | `*-staging-*` | `*-prod-*` |
| State file     | isolated   | isolated   | isolated    |

Everything else : VPC, subnets, NAT, security rules : is identical across environments. The workspace is the only lever.

---

## File Reference

### `provider.tf` : AWS Connection

```hcl
terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}
```

**What it does:**
Tells Terraform which cloud provider to use and how to connect to it.

**Why each part matters:**
- `required_version` : enforces a minimum Terraform CLI version. Protects against the project breaking silently on old installs.
- `required_providers` : pins the AWS plugin to major version 5. The `~>` operator means "5.x only, never jump to 6." This prevents unexpected breaking changes from provider upgrades.
- `provider "aws"` : the actual connection block. Region is pulled from `var.region` so it is never hardcoded. Change the tfvars value and the whole project re-targets a different region.

**Authentication:** Terraform reads your AWS credentials automatically from `~/.aws/credentials`, environment variables (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`), or an IAM instance role. No credentials are stored in any `.tf` file.

---

### `variables.tf` : Input Contract

Defines every configurable input the project accepts, with types and validation rules.

**Core variables:**

| Variable | Type | Default | Purpose |
|---|---|---|---|
| `region` | string | `us-east-1` | AWS region for all resources |
| `project_name` | string | _(required)_ | Prefix applied to every resource name |

**Networking variables:**

| Variable | Type | Default | Purpose |
|---|---|---|---|
| `vpc_cidr` | string | `10.0.0.0/16` | IP range for the entire VPC |
| `public_subnet_cidr` | string | `10.0.1.0/24` | IP range for the public subnet |
| `private_subnet_cidr` | string | `10.0.2.0/24` | IP range for the private subnet |

**Compute variables:**

| Variable | Type | Default | Purpose |
|---|---|---|---|
| `instance_type_map` | map(string) | dev=t2.micro, staging=t2.small, prod=t3.medium | Instance size per environment |
| `ami_id` | string | Amazon Linux 2 (us-east-1) | Base OS image for EC2 |

**Security variables:**

| Variable | Type | Default | Purpose |
|---|---|---|---|
| `allowed_ssh_cidr` | string | `0.0.0.0/0` | IP range allowed to SSH. Set to `x.x.x.x/32` in production. |

**Validation blocks:**
Every sensitive variable has a `validation` block. Terraform evaluates these before contacting AWS, rejecting bad input immediately:
- `region` : must match AWS region format (`us-east-1`, not `US East`)
- `project_name` : cannot be empty
- `allowed_ssh_cidr` : must be a valid CIDR notation

---

### `terraform.tfvars` : Actual Values

```hcl
region       = "us-east-1"
project_name = "multi-env-platform"
vpc_cidr     = "10.0.0.0/16"
...
```

**What it does:**
Supplies the real values for variables defined in `variables.tf`. Terraform loads this file automatically : you never reference it explicitly.

**Why this separation matters:**
- `variables.tf` = the definition (what inputs exist, what types they are)
- `terraform.tfvars` = the values (what those inputs actually are)

In a real team, different `.tfvars` files can be used for different contexts:
```bash
terraform apply -var-file="prod.tfvars"
terraform apply -var-file="dev.tfvars"
```

**Important:** Do not commit sensitive values (passwords, secret keys) to this file. Use environment variables or a secrets manager instead.

---

### `locals.tf` : Environment Logic

```hcl
locals {
  env           = terraform.workspace
  instance_type = lookup(var.instance_type_map, local.env, "t2.micro")
  name_prefix   = "${var.project_name}-${local.env}"
  common_tags   = { Project = var.project_name, Environment = local.env, ... }
}
```

**What it does:**
Reads the active workspace and derives all environment-specific values from it. This is where the multi-environment logic lives.

**Why each local matters:**

- `env` : captures `terraform.workspace` into a short name. Every other local and resource uses `local.env` rather than calling `terraform.workspace` directly. One place to change if the logic ever needs updating.

- `instance_type` : `lookup(map, key, default)` reads `var.instance_type_map` using the current environment as the key. If you're in the `prod` workspace, this resolves to `t3.medium`. If the workspace name doesn't exist in the map, it falls back to `"t2.micro"` instead of crashing.

- `name_prefix` : every resource in the project uses this as its name prefix. A VPC in dev becomes `multi-env-platform-dev-vpc`. A VPC in prod becomes `multi-env-platform-prod-vpc`. No manual renaming needed.

- `common_tags` : a map of tags applied to every AWS resource via `merge()`. In the AWS console you can filter all resources by `Environment = dev` or `ManagedBy = terraform`. Essential for cost tracking and auditing in real teams.

---

### `backend.tf` : Remote State

```hcl
terraform {
  backend "s3" {
    bucket       = "multi-env-platform-terraform-state"
    key          = "terraform/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}
```

**What it does:**
Moves the Terraform state file from your local machine to an S3 bucket. When workspaces are active, Terraform automatically namespaces the state path per environment:

```
s3://multi-env-platform-terraform-state/
  env:/
    dev/terraform/terraform.tfstate
    staging/terraform/terraform.tfstate
    prod/terraform/terraform.tfstate
```

**Why remote state matters:**
The state file is Terraform's source of truth : it maps your `.tf` definitions to real AWS resource IDs. If the state file lives only on your laptop:
- Teammates cannot run `terraform apply` safely
- A lost laptop means lost state, which means Terraform no longer knows what it created
- Two people running apply simultaneously will corrupt the state

**Why each setting matters:**
- `bucket` : the S3 bucket that stores all state files. Must exist before `terraform init` runs. Terraform cannot create its own backend.
- `key` : the path inside the bucket. Workspaces inject themselves automatically, so you don't need a separate key per environment.
- `use_lockfile = true` : writes a `.tflock` file to S3 at the start of every apply. If a second apply starts while the first is running, it reads the lock and refuses to proceed. Prevents state corruption from concurrent writes.
- `region` is hardcoded here intentionally. The backend block is processed before variables are loaded, so `var.region` is not available at this stage.

**One-time setup required:**
```bash
aws s3api create-bucket \
  --bucket multi-env-platform-terraform-state \
  --region us-east-1
```

---

### `networking.tf` : VPC, Subnets, IGW, NAT, Routes

The largest file. Builds the complete network topology in dependency order.

#### VPC

```hcl
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
}
```

Creates your isolated private network in AWS. Everything : subnets, EC2, NAT : lives inside this VPC. `enable_dns_hostnames = true` allows EC2 instances to get DNS names like `ec2-x-x-x-x.compute-1.amazonaws.com`, required for many AWS services to work correctly.

#### Public Subnet

```hcl
resource "aws_subnet" "public" {
  map_public_ip_on_launch = true
  availability_zone       = "${var.region}a"
}
```

Any instance launched here automatically receives a public IP address. The NAT Gateway lives in this subnet because it needs direct internet access to forward traffic on behalf of private instances.

#### Private Subnet

```hcl
resource "aws_subnet" "private" {
  # map_public_ip_on_launch defaults to false
}
```

No public IP is assigned. EC2 instances live here. They can initiate outbound connections (via NAT) but cannot be reached from the internet directly. This is the correct pattern for application servers.

#### Internet Gateway (IGW)

```hcl
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}
```

The door between your VPC and the public internet. Without it, even the public subnet is isolated. Attached directly to the VPC : one IGW per VPC.

#### Elastic IP + NAT Gateway

```hcl
resource "aws_eip" "nat" { domain = "vpc" }

resource "aws_nat_gateway" "nat" {
  subnet_id     = aws_subnet.public.id
  allocation_id = aws_eip.nat.id
  depends_on    = [aws_internet_gateway.igw]
}
```

The Elastic IP gives the NAT Gateway a fixed, static public IP address. This matters because external services can whitelist this single IP for all outbound traffic from your private instances.

The NAT Gateway sits in the public subnet and acts as a one-way door:
- Private EC2 → NAT → internet (allowed)
- Internet → private EC2 (blocked, NAT does not forward unsolicited inbound traffic)

`depends_on = [aws_internet_gateway.igw]` : Terraform normally figures out resource ordering from references. This explicit dependency is added because the NAT Gateway needs the IGW to be fully attached before it can route traffic, and that relationship is not obvious from the HCL references alone.

#### Route Tables

```hcl
# Public: send internet traffic through IGW
route { cidr_block = "0.0.0.0/0", gateway_id = igw.id }

# Private: send internet traffic through NAT
route { cidr_block = "0.0.0.0/0", nat_gateway_id = nat.id }
```

Route tables are the traffic rules for each subnet. `0.0.0.0/0` means "any destination not within the VPC." The public route table sends that traffic to the IGW. The private route table sends it to NAT. Each table is then associated with its matching subnet.

---

### `security.tf` : EC2 Security Group

```hcl
ingress { port 22,  cidr = var.allowed_ssh_cidr }  # SSH in
ingress { port all, cidr = var.vpc_cidr }           # Internal VPC traffic
egress  { port all, cidr = 0.0.0.0/0 }             # All outbound
```

**What it does:**
Acts as a stateful virtual firewall attached directly to the EC2 instance. Stateful means: if an inbound connection is allowed, the response is automatically permitted outbound : you do not need a matching egress rule for each ingress rule.

**Why each rule exists:**

- **SSH ingress (port 22)** : restricted to `var.allowed_ssh_cidr`. In a real deployment, set this to `YOUR_IP/32`. The default `0.0.0.0/0` is open for convenience during learning.

- **VPC-internal ingress** : allows all traffic originating from within the same VPC (`var.vpc_cidr`). Required if you later add a load balancer, another EC2, or any AWS service that communicates internally.

- **All egress** : allows the instance to make any outbound request. Required so EC2 can reach the internet through NAT to install packages, pull updates, and call external APIs.

---

### `compute.tf` : EC2 Instance

```hcl
resource "aws_instance" "app" {
  ami           = var.ami_id
  instance_type = local.instance_type      # t2.micro / t2.small / t3.medium
  subnet_id     = aws_subnet.private.id    # private subnet : no public IP
}
```

**What it does:**
Deploys the application server into the private subnet.

**Why each setting matters:**

- `instance_type = local.instance_type` : this is the payoff of the locals design. Switch workspace from dev to prod and the instance size changes automatically. No code edits required.

- `subnet_id = aws_subnet.private.id` : EC2 lives in the private subnet. It has no public IP and cannot be reached from the internet directly. This is the correct production pattern.

- `vpc_security_group_ids` : attaches the security group. Without this, AWS applies a default security group that blocks everything inbound.

- `root_block_device` with `gp3` : gp3 is the current-generation EBS volume type, faster and cheaper than the older gp2. `delete_on_termination = true` means the disk is cleaned up when the instance is destroyed, preventing orphaned volumes that accumulate cost.

- No `key_name` defined : the modern access pattern is AWS SSM Session Manager, which lets you open a shell session without managing SSH keys or opening port 22. Uncomment `key_name = "your-key"` if you prefer traditional SSH.

---

### `outputs.tf` : Exported Values

```hcl
output "environment"          { value = local.env }
output "vpc_id"               { value = aws_vpc.main.id }
output "public_subnet_id"     { value = aws_subnet.public.id }
output "private_subnet_id"    { value = aws_subnet.private.id }
output "ec2_instance_id"      { value = aws_instance.app.id }
output "ec2_private_ip"       { value = aws_instance.app.private_ip }
output "nat_gateway_public_ip"{ value = aws_eip.nat.public_ip }
```

**What it does:**
After `terraform apply` completes, these values are printed to the terminal and stored in the state file. They can be consumed by other Terraform projects using the `terraform_remote_state` data source.

**Why each output matters:**

- `environment` : confirms which workspace the apply ran against. Useful sanity check.
- `vpc_id` : needed if another Terraform project (e.g. an EKS cluster) needs to deploy into this VPC.
- `ec2_private_ip` : the private IP of your app server for internal routing rules.
- `nat_gateway_public_ip` : the single outbound IP used by all private instances. Whitelist this in external firewalls, third-party APIs, or partner systems.

---

## How to Use

### Prerequisites

- Terraform >= 1.3.0 installed
- AWS CLI configured (`aws configure`)
- S3 bucket created for state storage (one time):

```bash
aws s3api create-bucket \
  --bucket multi-env-platform-terraform-state \
  --region us-east-1
```

### Local Configuration

`terraform.tfvars` is excluded by `.gitignore` to prevent sensitive values from being committed. A template is provided:

```bash
cp terraform.tfvars.example terraform.tfvars
# then edit terraform.tfvars with your real values
```

### Initial Setup

```bash
# Download providers and connect to S3 backend
terraform init
```

### Create Workspaces

```bash
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod
```

### Deploy an Environment

```bash
# Switch to the environment you want
terraform workspace select dev

# Preview what will be created
terraform plan

# Deploy
terraform apply
```

### Switch Environments

```bash
terraform workspace select prod
terraform plan    # now plans with t3.medium, prod naming, prod state
terraform apply
```

### Check Active Environment

```bash
terraform workspace show    # prints: dev / staging / prod
terraform workspace list    # lists all workspaces, marks active with *
```

### Destroy an Environment

```bash
terraform workspace select dev
terraform destroy
```

---

## Key Design Principles

**Variables over hardcoding** : every value that could change lives in `variables.tf` and `terraform.tfvars`. Nothing is hardcoded in resource blocks.

**Locals for logic** : `locals.tf` is the single place that translates workspace name into environment behavior. Resource files are kept clean and declarative.

**Remote state** : state lives in S3, not on a laptop. Multiple people can run Terraform safely. The lockfile prevents concurrent writes.

**Private by default** : EC2 lives in the private subnet with no public IP. Only the NAT Gateway has a public IP, and only for outbound traffic.

**Validation at the boundary** : input validation blocks in `variables.tf` catch bad values before any AWS API calls are made.

**Tags on everything** : `local.common_tags` is merged into every resource. Enables cost filtering, compliance audits, and environment cleanup in the AWS console.
