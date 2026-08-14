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
# One route table per service, with global routes (all services) plus
# service-specific routes
# ---------------------------------------------------------------------------

resource "aws_route_table" "private" {
  for_each = { for svc in var.services : svc.name => svc }

  vpc_id = aws_vpc.this.id

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
    for_each = lookup(var.service_specific_routes, each.key, [])
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
    each.value.tags,
    {
      Name        = "${local.resource_prefix}-${each.value.name}-private-rt"
      Service     = each.value.name
      Environment = var.environment
    }
  )
}

resource "aws_route_table_association" "private" {
  for_each = local.subnets

  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.private[each.value.service_name].id
}
