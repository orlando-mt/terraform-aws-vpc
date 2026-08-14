output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "eks_subnet_ids" {
  description = "Subnets for the EKS service"
  value       = module.vpc.private_subnet_ids_by_service["eks"]
}

output "capacity" {
  description = "Subnet capacity summary"
  value       = module.vpc.subnet_capacity_info
}
