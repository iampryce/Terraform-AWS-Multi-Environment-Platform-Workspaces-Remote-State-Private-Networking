resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-vpc" })
}

# ── Subnets ───────────────────────────────────────────────────────────────────

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true # instances here get a public IP

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-public-subnet" })
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = "${var.region}a"
  # map_public_ip_on_launch defaults to false — no public IP assigned

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-private-subnet" })
}

# ── Internet Gateway ──────────────────────────────────────────────────────────

# Without this, even the public subnet has no internet access
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-igw" })
}

# ── NAT Gateway ───────────────────────────────────────────────────────────────

# Static public IP for the NAT Gateway — all private instance traffic exits via this IP
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-nat-eip" })
}

# Allows private instances to reach the internet — blocks all inbound traffic
resource "aws_nat_gateway" "nat" {
  subnet_id     = aws_subnet.public.id # NAT must sit in the public subnet
  allocation_id = aws_eip.nat.id

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-nat" })

  depends_on = [aws_internet_gateway.igw] # IGW must exist before NAT can route
}

# ── Route Tables ──────────────────────────────────────────────────────────────

# Public: non-VPC traffic goes out through the IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-public-rt" })
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Private: non-VPC traffic goes through NAT instead of directly to the internet
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-private-rt" })
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}
