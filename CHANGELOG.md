# Changelog

## [2.0.0] - 2026-08-16

### Added
- Optional internet edge: public subnets, internet gateway and NAT
  gateways, either one per availability zone or a single shared one
- Public subnet tags input, for load balancer discovery
- Outputs for public subnets, internet gateway, NAT gateways and the
  egress addresses used for partner allow-lists

### Changed
- **Breaking:** private route tables are now created per service *and*
  availability zone instead of one per service, so each zone can egress
  through the NAT gateway in its own zone. The `private_route_table_ids`
  output is now keyed `<service>-<az index>`; use the new
  `private_route_table_ids_by_service` output for the previous grouping.
- Subnet capacity validation and the capacity output now account for the
  public subnets

## [1.0.0] - 2026-07-30

### Added
- Initial release: service-segmented private VPC — one private subnet per
  service per AZ, carved deterministically from the VPC CIDR, with a
  dedicated route table per service
- Global routes (all services) and per-service routes (TGW, peering,
  NAT, IGW targets)
- VPC Flow Logs to CloudWatch enabled by default, with in-module IAM
  role (or external role), configurable retention, traffic type and
  optional KMS encryption
- Default security group adopted and emptied (all traffic denied on it)
- Subnet capacity validation (services x AZs vs available subnet space)
  and capacity summary output
