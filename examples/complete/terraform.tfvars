region      = "us-east-1"
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

# Uncomment to route all egress through a Transit Gateway
# transit_gateway_id = "tgw-00000000000000000"

common_tags = {
  Project   = "example"
  ManagedBy = "terraform"
}
