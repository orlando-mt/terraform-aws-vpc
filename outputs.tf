output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.this.id
}

output "vpc_arn" {
  description = "ARN of the VPC"
  value       = aws_vpc.this.arn
}

output "vpc_name" {
  description = "Name of the VPC"
  value       = local.vpc_name
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.this.cidr_block
}

output "availability_zones" {
  description = "Availability zones used"
  value       = local.azs
}

# --- Subnets ---------------------------------------------------------------

output "private_subnet_ids_by_service" {
  description = "Private subnet IDs grouped by service"
  value = {
    for svc in var.services : svc.name => [
      for az_idx in range(var.az_count) : aws_subnet.private["${svc.name}-${az_idx}"].id
    ]
  }
}

output "private_subnet_ids_all" {
  description = "All private subnet IDs"
  value       = [for subnet in aws_subnet.private : subnet.id]
}

output "private_subnet_cidrs_by_service" {
  description = "Private subnet CIDR blocks grouped by service"
  value       = local.service_cidrs
}

# --- Public subnets and egress ---------------------------------------------

output "public_subnet_ids" {
  description = "Public subnet IDs, one per availability zone (empty when not created)"
  value       = [for k in sort(keys(aws_subnet.public)) : aws_subnet.public[k].id]
}

output "public_subnet_cidrs" {
  description = "CIDR blocks of the public subnets"
  value       = [for k in sort(keys(aws_subnet.public)) : aws_subnet.public[k].cidr_block]
}

output "internet_gateway_id" {
  description = "Internet gateway ID (null when not created)"
  value       = local.create_public ? aws_internet_gateway.this[0].id : null
}

output "nat_gateway_ids" {
  description = "NAT gateway IDs, keyed by availability zone index"
  value       = { for k, v in aws_nat_gateway.this : k => v.id }
}

output "nat_public_ips" {
  description = "Public addresses used for egress. These are the addresses a partner would allow-list"
  value       = [for k in sort(keys(aws_eip.nat)) : aws_eip.nat[k].public_ip]
}

output "public_route_table_id" {
  description = "Route table of the public subnets (null when not created)"
  value       = local.create_public ? aws_route_table.public[0].id : null
}

# --- Routing ---------------------------------------------------------------

output "private_route_table_ids" {
  description = "Private route table IDs, keyed by <service>-<az index>"
  value       = { for k, rt in aws_route_table.private : k => rt.id }
}

output "private_route_table_ids_by_service" {
  description = "Private route table IDs grouped by service, for VPC Gateway endpoints"
  value = {
    for svc in var.services : svc.name => [
      for az_idx in range(var.az_count) : aws_route_table.private["${svc.name}-${az_idx}"].id
    ]
  }
}

# --- Capacity --------------------------------------------------------------

output "subnet_capacity_info" {
  description = "Subnet capacity summary for the chosen CIDR and newbits"
  value = {
    vpc_cidr             = var.vpc_cidr
    subnet_newbits       = var.subnet_newbits
    max_subnets_possible = pow(2, var.subnet_newbits)
    subnets_used         = (length(var.services) * var.az_count) + (local.create_public ? var.az_count : 0)
    subnets_remaining    = pow(2, var.subnet_newbits) - (length(var.services) * var.az_count) - (local.create_public ? var.az_count : 0)
  }
}

# --- Flow logs -------------------------------------------------------------

output "flow_log_id" {
  description = "ID of the VPC Flow Log (null if disabled)"
  value       = var.enable_flow_logs ? aws_flow_log.this[0].id : null
}

output "flow_logs_log_group_name" {
  description = "CloudWatch log group for flow logs (null if disabled)"
  value       = var.enable_flow_logs ? aws_cloudwatch_log_group.flow_logs[0].name : null
}

output "flow_logs_role_arn" {
  description = "IAM role used by flow logs (null if disabled)"
  value       = var.enable_flow_logs ? coalesce(var.flow_logs_role_arn, try(aws_iam_role.flow_logs[0].arn, null)) : null
}
