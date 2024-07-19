data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  az_count = length(data.aws_availability_zones.available.names)
}

resource "aws_vpc" "primary" {
  cidr_block                       = element(var.aws_rfc1918, 1)
  assign_generated_ipv6_cidr_block = var.enable_ipv6

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = var.vpc_name
  }
}

resource "aws_subnet" "public" {
  count = local.az_count

  vpc_id            = aws_vpc.primary.id
  availability_zone = element(data.aws_availability_zones.available.names, count.index)

  # -- Addressing: IPv4
  cidr_block              = cidrsubnet(aws_vpc.primary.cidr_block, 8, count.index)
  map_public_ip_on_launch = var.public_subnet_auto_assign_public_ipv4

  # -- Addressing: IPv6
  ipv6_cidr_block = (
    var.enable_ipv6 && var.public_subnet_enable_ipv6
    ? cidrsubnet(aws_vpc.primary.ipv6_cidr_block, 8, count.index) : null
  )

  ipv6_native = (var.enable_ipv6 && var.public_subnet_enable_ipv6 && var.public_subnet_ipv6_only)

  assign_ipv6_address_on_creation = (
    var.enable_ipv6
    && var.public_subnet_enable_ipv6
    && var.public_subnet_auto_assign_ipv6
  )

  # -- DNS & Hostnames
  enable_dns64 = (var.enable_ipv6 && var.public_subnet_enable_ipv6 && var.public_subnet_enable_dns64)

  tags = {
    Name = join("-", ["public", count.index])
  }
}

resource "aws_subnet" "private" {
  count = local.az_count

  vpc_id            = aws_vpc.primary.id
  availability_zone = element(data.aws_availability_zones.available.names, count.index)

  # -- Addressing: IPv4
  cidr_block              = cidrsubnet(aws_vpc.primary.cidr_block, 8, count.index + local.az_count)
  map_public_ip_on_launch = var.public_subnet_auto_assign_public_ipv4

  # -- Addressing: IPv6
  ipv6_native = (var.enable_ipv6 && var.private_subnet_enable_ipv6 && var.private_subnet_ipv6_only)

  ipv6_cidr_block = (
    var.enable_ipv6 && var.private_subnet_enable_ipv6
    ? cidrsubnet(aws_vpc.primary.ipv6_cidr_block, 8, count.index + local.az_count) : null
  )

  # -- DNS & Hostnames
  enable_dns64 = (var.enable_ipv6 && var.public_subnet_enable_ipv6 && var.public_subnet_enable_dns64)

  tags = {
    Name = join("-", ["Private", count.index])
  }
}

resource "aws_subnet" "ipv6-only" {
  count = local.az_count

  vpc_id            = aws_vpc.primary.id
  availability_zone = element(data.aws_availability_zones.available.names, count.index)

  # -- Addressing: IPv4

  # -- Addressing: IPv6
  ipv6_cidr_block = cidrsubnet(aws_vpc.primary.ipv6_cidr_block, 8, count.index + (local.az_count * 2))

  ipv6_native                     = true
  assign_ipv6_address_on_creation = true

  # -- DNS & Hostnames
  enable_dns64                                   = true
  enable_resource_name_dns_aaaa_record_on_launch = true

  tags = {
    Name = join("-", ["IPv6-only", count.index])
  }
}

resource "aws_eip" "ngw" {
  domain = "vpc"
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.primary.id
}

resource "aws_nat_gateway" "ngw" {
  allocation_id = aws_eip.ngw.allocation_id
  subnet_id     = element(aws_subnet.public[*].id, 1)

  depends_on = [
    aws_internet_gateway.igw
  ]
}

resource "aws_egress_only_internet_gateway" "eigw" {
  vpc_id = aws_vpc.primary.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.primary.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.igw.id
  }

  route {
    ipv6_cidr_block = "64:ff9b::/96"
    nat_gateway_id  = aws_nat_gateway.ngw.id
  }

  tags = {
    Name = "Public Routes"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.primary.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ngw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    egress_only_gateway_id = aws_egress_only_internet_gateway.eigw.id
  }

  route {
    ipv6_cidr_block = "64:ff9b::/96"
    nat_gateway_id  = aws_nat_gateway.ngw.id
  }

  tags = {
    Name = "Private Routes"
  }
}

resource "aws_route_table" "ipv6-only" {
  vpc_id = aws_vpc.primary.id

  route {
    ipv6_cidr_block        = "::/0"
    egress_only_gateway_id = aws_egress_only_internet_gateway.eigw.id
  }

  route {
    ipv6_cidr_block = "64:ff9b::/96"
    nat_gateway_id  = aws_nat_gateway.ngw.id
  }

  tags = {
    Name = "IPv6-native Routes"
  }
}

// NOTE: We could in theory have the following in place
//     for_each = toset([for subnet in aws_subnet.private: subnet.id])
// However, that would mean both each.key and each.value are computed at run-time
//   which is not allowed. So at a minimum each.key should be static and each.value
//   can be computed at apply-time. So we use zipmap with range of length we already
//   know to create a faux static each.key and an apply-time each.value
//
resource "aws_route_table_association" "private" {
  for_each       = zipmap(range(local.az_count), aws_subnet.private[*].id)
  subnet_id      = each.value
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "ipv6-only" {
  for_each       = zipmap(range(local.az_count), aws_subnet.ipv6-only[*].id)
  subnet_id      = each.value
  route_table_id = aws_route_table.ipv6-only.id
}

resource "aws_route_table_association" "public" {
  for_each       = zipmap(range(local.az_count), aws_subnet.public[*].id)
  subnet_id      = each.value
  route_table_id = aws_route_table.public.id
}

resource "aws_ec2_managed_prefix_list" "admin-v4" {
  address_family = "IPv4"
  name           = "Admin IPv4 Prefix List"
  max_entries    = 20

  lifecycle {
    ignore_changes = [
      entry,
    ]
  }
}

resource "aws_ec2_managed_prefix_list" "admin-v6" {
  address_family = "IPv6"
  name           = "Admin IPv6 Prefix List"
  max_entries    = 20

  lifecycle {
    ignore_changes = [
      entry,
    ]
  }
}

resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.primary.id

  ingress {
    protocol  = -1
    self      = true
    from_port = 0
    to_port   = 0
  }

  ingress {
    description = "Allow SSH access from user-managed prefix-lists"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    prefix_list_ids = [
      aws_ec2_managed_prefix_list.admin-v4.id,
      aws_ec2_managed_prefix_list.admin-v6.id
    ]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  depends_on = [
    aws_ec2_managed_prefix_list.admin-v4,
    aws_ec2_managed_prefix_list.admin-v6
  ]
}
