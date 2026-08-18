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

# --- Egress: pick one of the two designs -----------------------------------
#
# Distributed egress: this VPC provides its own internet access. One NAT per
# zone avoids cross-zone transfer and keeps a zone failure contained.
create_public_subnets = true
nat_gateway_mode      = "per_az"

# Tags the AWS Load Balancer Controller looks for when placing an
# internet-facing load balancer
public_subnet_tags = {
  "kubernetes.io/role/elb" = "1"
}

# Centralised egress: leave nat_gateway_mode = "none", skip the public
# subnets, and send the default route to a Transit Gateway in the network
# account instead.
# create_public_subnets = false
# nat_gateway_mode      = "none"
# transit_gateway_id    = "tgw-00000000000000000"

common_tags = {
  Project   = "example"
  ManagedBy = "terraform"
}
