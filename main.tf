data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  resource_prefix = "${var.name_prefix}-${var.environment}"
  vpc_name        = "${local.resource_prefix}-vpc"

  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # One private subnet per service per AZ. CIDRs are carved sequentially:
  # service index * az_count + az index.
  subnets = {
    for pair in flatten([
      for svc_idx, svc in var.services : [
        for az_idx in range(var.az_count) : {
          key           = "${svc.name}-${az_idx}"
          service_name  = svc.name
          service_index = svc_idx
          az_index      = az_idx
          service_tags  = svc.tags
        }
      ]
    ]) : pair.key => pair
  }

  service_cidrs = {
    for svc_idx, svc in var.services : svc.name => [
      for az_idx in range(var.az_count) :
      cidrsubnet(var.vpc_cidr, var.subnet_newbits, svc_idx * var.az_count + az_idx)
    ]
  }

  # Public subnets are carved from the top of the address space while service
  # subnets grow from the bottom, so adding a service never renumbers them.
  public_subnet_indexes = {
    for az_idx in range(var.az_count) :
    az_idx => pow(2, var.subnet_newbits) - var.az_count + az_idx
  }

  create_public = var.create_public_subnets || var.nat_gateway_mode != "none"

  # One NAT per AZ keeps egress inside the zone; a single NAT is cheaper but
  # sends traffic across zones and fails with the AZ that holds it.
  nat_az_indexes = var.nat_gateway_mode == "per_az" ? range(var.az_count) : (
    var.nat_gateway_mode == "single" ? [0] : []
  )

  # Route table per service and AZ, so each one can point at the NAT in its
  # own zone.
  nat_gateway_for_az = {
    for az_idx in range(var.az_count) :
    az_idx => var.nat_gateway_mode == "per_az" ? az_idx : 0
  }
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = var.enable_dns_support
  enable_dns_hostnames = var.enable_dns_hostnames

  tags = merge(
    var.common_tags,
    {
      Name        = local.vpc_name
      Environment = var.environment
    }
  )
}

# ---------------------------------------------------------------------------
# Default security group: adopted and emptied. With no ingress/egress rules
# declared, all traffic on the VPC's default SG is denied, forcing workloads
# to use explicit, purpose-built security groups.
# ---------------------------------------------------------------------------

resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    var.common_tags,
    {
      Name        = "${local.vpc_name}-default-sg-locked"
      Environment = var.environment
    }
  )
}

# ---------------------------------------------------------------------------
# Private subnets: one per service per AZ
# ---------------------------------------------------------------------------

resource "aws_subnet" "private" {
  for_each = local.subnets

  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, var.subnet_newbits, each.value.service_index * var.az_count + each.value.az_index)
  availability_zone = local.azs[each.value.az_index]

  tags = merge(
    var.common_tags,
    each.value.service_tags,
    {
      Name        = "${local.resource_prefix}-${each.value.service_name}-private-${each.value.az_index + 1}"
      Service     = each.value.service_name
      Environment = var.environment
    }
  )
}

# ---------------------------------------------------------------------------
# Internet edge: public subnets, internet gateway and NAT gateways.
#
# Created only when the VPC provides its own egress. In a centralised egress
# design these stay disabled and the default route is injected through
# custom_routes towards a Transit Gateway instead.
# ---------------------------------------------------------------------------

resource "aws_internet_gateway" "this" {
  count = local.create_public ? 1 : 0

  vpc_id = aws_vpc.this.id

  tags = merge(
    var.common_tags,
    {
      Name        = "${local.vpc_name}-igw"
      Environment = var.environment
    }
  )
}

resource "aws_subnet" "public" {
  for_each = local.create_public ? local.public_subnet_indexes : {}

  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, var.subnet_newbits, each.value)
  availability_zone = local.azs[each.key]

  # Instances get public addresses explicitly, never by default
  map_public_ip_on_launch = var.map_public_ip_on_launch

  tags = merge(
    var.common_tags,
    var.public_subnet_tags,
    {
      Name        = "${local.resource_prefix}-public-${each.key + 1}"
      Tier        = "public"
      Environment = var.environment
    }
  )
}

resource "aws_route_table" "public" {
  count = local.create_public ? 1 : 0

  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this[0].id
  }

  tags = merge(
    var.common_tags,
    {
      Name        = "${local.resource_prefix}-public-rt"
      Environment = var.environment
    }
  )
}

resource "aws_route_table_association" "public" {
  for_each = local.create_public ? local.public_subnet_indexes : {}

  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_eip" "nat" {
  for_each = toset([for i in local.nat_az_indexes : tostring(i)])

  domain = "vpc"

  tags = merge(
    var.common_tags,
    {
      Name        = "${local.resource_prefix}-nat-${tonumber(each.value) + 1}"
      Environment = var.environment
    }
  )

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  for_each = toset([for i in local.nat_az_indexes : tostring(i)])

  allocation_id = aws_eip.nat[each.value].id
  subnet_id     = aws_subnet.public[tonumber(each.value)].id

  tags = merge(
    var.common_tags,
    {
      Name        = "${local.resource_prefix}-nat-${tonumber(each.value) + 1}"
      Environment = var.environment
    }
  )

  depends_on = [aws_internet_gateway.this]
}

# ---------------------------------------------------------------------------
# One route table per service and availability zone.
#
# Per-AZ tables are what allow each zone to egress through the NAT gateway in
# its own zone: a single table per service would force every zone through one
# NAT, paying cross-AZ transfer and losing the isolation NAT redundancy buys.
# ---------------------------------------------------------------------------

resource "aws_route_table" "private" {
  for_each = local.subnets

  vpc_id = aws_vpc.this.id

  # Default route through the NAT gateway of this availability zone
  dynamic "route" {
    for_each = var.nat_gateway_mode != "none" ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.this[tostring(local.nat_gateway_for_az[each.value.az_index])].id
    }
  }

  # Routes shared by all services
  dynamic "route" {
    for_each = var.custom_routes
    content {
      cidr_block                = route.value.cidr_block
      vpc_peering_connection_id = route.value.vpc_peering_connection_id
      transit_gateway_id        = route.value.transit_gateway_id
      nat_gateway_id            = route.value.nat_gateway_id
      gateway_id                = route.value.gateway_id
    }
  }

  # Service-specific routes
  dynamic "route" {
    for_each = lookup(var.service_specific_routes, each.value.service_name, [])
    content {
      cidr_block                = route.value.cidr_block
      vpc_peering_connection_id = route.value.vpc_peering_connection_id
      transit_gateway_id        = route.value.transit_gateway_id
      nat_gateway_id            = route.value.nat_gateway_id
      gateway_id                = route.value.gateway_id
    }
  }

  tags = merge(
    var.common_tags,
    each.value.service_tags,
    {
      Name        = "${local.resource_prefix}-${each.value.service_name}-private-rt-${each.value.az_index + 1}"
      Service     = each.value.service_name
      Environment = var.environment
    }
  )
}

resource "aws_route_table_association" "private" {
  for_each = local.subnets

  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.private[each.key].id
}
