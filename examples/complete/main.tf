provider "aws" {
  region = var.region
}

module "vpc" {
  source = "../../"

  name_prefix = var.name_prefix
  environment = var.environment

  vpc_cidr       = var.vpc_cidr
  subnet_newbits = var.subnet_newbits
  az_count       = var.az_count

  services = var.services

  custom_routes = var.transit_gateway_id != null ? [
    {
      cidr_block         = "0.0.0.0/0"
      transit_gateway_id = var.transit_gateway_id
    }
  ] : []

  common_tags = var.common_tags
}
