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

# --- Routing ---------------------------------------------------------------

output "private_route_table_ids" {
  description = "Route table IDs per service"
  value       = { for name, rt in aws_route_table.private : name => rt.id }
}

# --- Capacity --------------------------------------------------------------

output "subnet_capacity_info" {
  description = "Subnet capacity summary for the chosen CIDR and newbits"
  value = {
    vpc_cidr             = var.vpc_cidr
    subnet_newbits       = var.subnet_newbits
    max_subnets_possible = pow(2, var.subnet_newbits)
    subnets_used         = length(var.services) * var.az_count
    subnets_remaining    = pow(2, var.subnet_newbits) - (length(var.services) * var.az_count)
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
