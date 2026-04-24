# Multi-Environment AWS Infrastructure using Terraform Workspaces

Designed and implemented a production-style AWS infrastructure using Terraform with environment isolation, secure networking, and scalable configuration.

---

## Project Summary

This project deploys isolated AWS infrastructure across three environments (dev, staging, prod) from a single codebase. The active Terraform workspace drives all environment-specific behaviour : no duplicated folders, no separate codebases.

**Production practices applied:**
- Private EC2 instances with no direct internet exposure
- Outbound-only internet access via NAT Gateway
- Dynamic AMI resolution : no hardcoded image IDs
- Remote state in S3 with native locking
- Input validation on all variables
- Consistent tagging across every resource

---

## Key Skills Demonstrated

- Terraform (Infrastructure as Code)
- AWS Networking : VPC, Subnets, IGW, NAT Gateway, Route Tables
- Multi-environment design using Terraform Workspaces
- Remote state management : S3 backend with lockfile
- Dynamic data sources : AMI lookup at plan time
- Secure infrastructure design : private subnets, restricted SSH, security groups
- Input validation and environment-aware locals

---

## Problem This Solves

Managing multiple environments often leads to duplicated code, inconsistent configurations, and state conflicts. This project solves that by using Terraform Workspaces to isolate environments while maintaining a single, reusable codebase.

---

## Architecture

This architecture follows a secure, production-style network design with isolated private workloads and controlled outbound internet access.

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
   │     NAT Gateway ── Elastic IP
   │
   ▼
Private Subnet (10.0.2.0/24)
   │
   ▼
EC2 Instance
   │
Security Group
```

**Traffic rules:**
- Public subnet → internet via IGW (direct)
- Private EC2 → internet via NAT (outbound only)
- Internet → private EC2 (blocked)
- SSH restricted to `allowed_ssh_cidr`

---

## Environment Differences

| | dev | staging | prod |
|---|---|---|---|
| EC2 size | t2.micro | t2.small | t3.medium |
| Resource names | `*-dev-*` | `*-staging-*` | `*-prod-*` |
| State file | isolated | isolated | isolated |

All environments share identical infrastructure definitions. The active workspace is the only variable controlling behaviour.

---

## File Structure

```
provider.tf             AWS provider and version constraints
backend.tf              S3 remote state with workspace namespacing
variables.tf            All input variables with types and validation
terraform.tfvars        Your actual values (gitignored)
terraform.tfvars.example  Safe template to copy and fill in
locals.tf               Environment logic : name prefix, instance size, tags
data.tf                 Dynamic AMI lookup (latest Amazon Linux 2)
networking.tf           VPC, subnets, IGW, NAT Gateway, route tables
security.tf             EC2 security group : SSH, VPC traffic, egress
compute.tf              EC2 instance in private subnet
outputs.tf              VPC ID, instance ID, private IP, NAT public IP
.gitignore              Blocks state files, .terraform/, terraform.tfvars
```

---

## File Reference

### `provider.tf`
Connects Terraform to AWS. Pins the provider to version 5.x to prevent breaking changes from automatic upgrades. Region is read from `var.region` : never hardcoded.

Credentials are not stored here. Terraform reads them from `~/.aws/credentials`, environment variables, or an IAM role automatically.

---

### `backend.tf`
Stores state in S3 instead of locally. Each workspace gets its own isolated state file automatically:

```
s3://multi-env-platform-terraform-state/
  env:/dev/terraform/terraform.tfstate
  env:/staging/terraform/terraform.tfstate
  env:/prod/terraform/terraform.tfstate
```

`use_lockfile = true` prevents two applies from running at the same time and corrupting state.

> The S3 bucket must be created manually before `terraform init` : Terraform cannot create its own backend.

---

### `variables.tf`
Defines every input the project accepts. All variables have types and descriptions. Sensitive ones have `validation` blocks that reject bad values before any AWS call is made.

| Variable | Default | Purpose |
|---|---|---|
| `region` | `us-east-1` | AWS region for all resources |
| `project_name` | required | Prefix on every resource name |
| `owner` | `""` | Responsible team : applied as a tag |
| `additional_tags` | `{}` | Extra tags merged into every resource |
| `vpc_cidr` | `10.0.0.0/16` | VPC IP range |
| `public_subnet_cidr` | `10.0.1.0/24` | Public subnet IP range |
| `private_subnet_cidr` | `10.0.2.0/24` | Private subnet IP range |
| `instance_type_map` | dev=t2.micro, staging=t2.small, prod=t3.medium | EC2 size per environment |
| `ssh_key_name` | `null` | EC2 key pair name. `null` = SSM access only |
| `allowed_ssh_cidr` | `0.0.0.0/0` | IPs allowed to SSH. Use `x.x.x.x/32` in production |

**Validated variables:** `region`, `project_name`, `vpc_cidr`, `public_subnet_cidr`, `private_subnet_cidr`, `allowed_ssh_cidr`

---

### `terraform.tfvars`
Supplies actual values for variables. Terraform loads this automatically. Excluded from Git via `.gitignore` to prevent committing sensitive data.

Copy the example to get started:
```bash
cp terraform.tfvars.example terraform.tfvars
```

---

### `locals.tf`
Translates the active workspace into environment-specific values used across all resource files.

| Local | Value | Purpose |
|---|---|---|
| `env` | `terraform.workspace` | Active environment name |
| `instance_type` | lookup from `instance_type_map` | Correct EC2 size for this env |
| `name_prefix` | `{project_name}-{env}` | Prefix for every resource name |
| `common_tags` | merged tag map | Applied to every resource |

---

### `data.tf`
Queries AWS at plan time for the latest Amazon Linux 2 AMI. This replaces a hardcoded AMI ID, which is region-specific and goes stale as AWS releases updated images.

Referenced in `compute.tf` as `data.aws_ami.amazon_linux.id`.

---

### `networking.tf`
Builds the full network topology in dependency order.

| Resource | Purpose |
|---|---|
| `aws_vpc` | Isolated private network : everything lives here |
| `aws_subnet public` | Internet-facing tier : NAT Gateway lives here |
| `aws_subnet private` | Secure tier : EC2 lives here, no public IP |
| `aws_internet_gateway` | Connects public subnet to the internet |
| `aws_eip` | Static public IP for the NAT Gateway |
| `aws_nat_gateway` | Outbound-only internet for private instances |
| `aws_route_table public` | Routes non-VPC traffic → IGW |
| `aws_route_table private` | Routes non-VPC traffic → NAT |

---

### `security.tf`
A stateful firewall attached to the EC2 instance. Stateful means response traffic is automatically allowed : no matching egress rule needed per ingress rule.

| Rule | Port | Source | Purpose |
|---|---|---|---|
| Ingress | 22 | `allowed_ssh_cidr` | SSH access |
| Ingress | all | `vpc_cidr` | Internal VPC communication |
| Egress | all | `0.0.0.0/0` | Outbound for updates and API calls |

---

### `compute.tf`
Deploys the EC2 app server into the private subnet.

- AMI resolved dynamically from `data.tf` : always current, always region-correct
- Instance size from `local.instance_type` : changes with the workspace
- No public IP : sits in private subnet
- `key_name = null` by default : use SSM Session Manager for access
- `gp3` volume : faster and cheaper than gp2, deleted on destroy

---

### `outputs.tf`
Values printed after `terraform apply` and stored in state.

| Output | Use |
|---|---|
| `environment` | Confirms which workspace was deployed |
| `vpc_id` | Reference from other Terraform projects |
| `public_subnet_id` | For deploying load balancers or bastion hosts |
| `private_subnet_id` | For deploying additional private resources |
| `ec2_instance_id` | Connect via SSM: `aws ssm start-session --target <id>` |
| `ec2_private_ip` | Internal routing and DNS |
| `nat_gateway_public_ip` | Whitelist in external firewalls and APIs |

---

## How to Use

### One-time setup

Create the S3 state bucket:
```bash
aws s3api create-bucket \
  --bucket multi-env-platform-terraform-state \
  --region us-east-1
```

Copy and fill in your variables:
```bash
cp terraform.tfvars.example terraform.tfvars
```

Initialise Terraform:
```bash
terraform init
```

Create workspaces:
```bash
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod
```

### Deploy

```bash
terraform workspace select dev
terraform plan
terraform apply
```

### Switch environments

```bash
terraform workspace select prod
terraform plan    # same code, t3.medium, prod state
terraform apply
```

### Useful commands

```bash
terraform workspace show     # print active environment
terraform workspace list     # list all workspaces
terraform output             # print outputs after apply
terraform destroy            # destroy the active environment
```

---

## Design Principles

**Variables over hardcoding** : every value that could change is an input variable. Nothing is hardcoded in resource files.

**Locals for logic** : `locals.tf` is the single place that translates workspace name into environment behaviour. Resource files stay declarative.

**Remote state** : state lives in S3. Multiple people can work safely. The lockfile prevents concurrent corruption.

**Private by default** : EC2 has no public IP. The only public IP in the project belongs to the NAT Gateway, used for outbound traffic only.

**Dynamic over static** : the AMI is resolved at plan time, not hardcoded. The project stays current without manual updates.

**Validation at the boundary** : bad inputs are rejected before Terraform contacts AWS.

**Tags on everything** : `local.common_tags` is merged into every resource for cost tracking, compliance, and environment filtering in the AWS console.

---

## Trade-offs

- Terraform Workspaces simplify environment management but can become harder to manage at scale compared to separate environment directories. For larger teams, a directory-per-environment structure may offer clearer separation.
- S3 native locking (`use_lockfile`) was used for simplicity. DynamoDB locking is an alternative that provides stronger consistency guarantees in larger team environments.
- A single availability zone is used per subnet. A production system would span multiple AZs for high availability.
