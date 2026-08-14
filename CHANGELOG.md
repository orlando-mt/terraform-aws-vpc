# Changelog

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
