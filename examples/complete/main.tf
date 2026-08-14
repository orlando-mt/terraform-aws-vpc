provider "aws" {
  region = var.region
}

module "vpc" {
  source = "../../"

  name_prefix = "example"
  environment = "dev"

  vpc_cidr       = "10.20.0.0/16"
  subnet_newbits = 5 # /21 subnets, up to 32
  az_count       = 3

  # Each service gets 3 private subnets (one per AZ) and its own route table
  services = [
    { name = "eks" },
    { name = "databases" },
    { name = "messaging", tags = { Tier = "streaming" } }
  ]

  # Example: route all egress through a Transit Gateway
  custom_routes = var.transit_gateway_id != null ? [
    {
      cidr_block         = "0.0.0.0/0"
      transit_gateway_id = var.transit_gateway_id
    }
  ] : []

  common_tags = {
    Project   = "example"
    ManagedBy = "terraform"
  }
}
