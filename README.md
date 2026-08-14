# terraform-aws-vpc

Terraform module to create a **service-segmented private VPC**: each service gets one private subnet per availability zone, carved deterministically from the VPC CIDR, with its own route table.

## Design

This module implements a private-only network layout intended for landing-zone architectures:

- **No public subnets, IGW or NAT are created.** Egress and cross-VPC connectivity are injected via routes (Transit Gateway, VPC peering, or NAT/IGW managed elsewhere) using `custom_routes` (all services) and `service_specific_routes` (per service).
- **Segmentation by service, not by tier.** Instead of the classic public/private/data split, subnets are grouped per workload (e.g. `eks`, `databases`, `messaging`), which gives each service an isolated CIDR range and independent routing — useful for security zoning, firewall rules by range, and clean IPAM.
- **Deterministic CIDR math.** Subnet CIDRs derive from the service and AZ index, so adding a service never renumbers existing subnets (append new services at the end of the list).

## Features

- One private subnet per service per AZ (`az_count`, 2-4) with a dedicated route table per service
- Global and per-service custom routes (TGW, peering, NAT, IGW targets)
- VPC Flow Logs to CloudWatch **enabled by default**, with the IAM role created in-module (or bring your own), configurable retention/traffic type and optional KMS encryption
- **Default security group locked down**: the module adopts the VPC's default SG and removes all its rules, so nothing can accidentally rely on it
- Capacity validation at plan time (services x AZs vs `2^subnet_newbits`) plus a `subnet_capacity_info` output for IPAM visibility
- Validations: valid CIDR, unique service names, AZ count range

## Usage

```hcl
module "vpc" {
  source = "github.com/orlando-mt/terraform-aws-vpc?ref=v1.0.0"

  name_prefix = "myapp"
  environment = "prod"

  vpc_cidr       = "10.20.0.0/16"
  subnet_newbits = 5

  services = [
    { name = "eks" },
    { name = "databases" },
    { name = "messaging" }
  ]

  custom_routes = [
    {
      cidr_block         = "0.0.0.0/0"
      transit_gateway_id = "tgw-0abc123"
    }
  ]

  common_tags = {
    Project   = "my-project"
    ManagedBy = "terraform"
  }
}
```

> **Tip:** the `private_subnet_ids_by_service` output feeds directly into the other modules of this portfolio — e.g. `["eks"]` into the EKS cluster, `["databases"]` into [terraform-aws-rds](https://github.com/orlando-mt/terraform-aws-rds) / [terraform-aws-documentdb](https://github.com/orlando-mt/terraform-aws-documentdb), `["messaging"]` into [terraform-aws-msk](https://github.com/orlando-mt/terraform-aws-msk).

## Examples

- [Complete](./examples/complete)

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.9.0 |
| aws | >= 5.0 |

## Resources

| Name | Type |
|------|------|
| aws_vpc.this | resource |
| aws_default_security_group.this | resource |
| aws_subnet.private | resource |
| aws_route_table.private | resource |
| aws_route_table_association.private | resource |
| aws_flow_log.this | resource |
| aws_cloudwatch_log_group.flow_logs | resource |
| aws_iam_role.flow_logs | resource |
| aws_iam_role_policy.flow_logs | resource |
| aws_availability_zones.available | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name_prefix | Prefix for all resource names | `string` | n/a | yes |
| environment | Deployment environment | `string` | n/a | yes |
| vpc_cidr | VPC CIDR block | `string` | n/a | yes |
| services | Services (name + optional tags) | `list(object)` | n/a | yes |
| subnet_newbits | Bits to carve subnets | `number` | `5` | no |
| az_count | AZs per service (2-4) | `number` | `3` | no |
| custom_routes | Routes for all route tables | `list(object)` | `[]` | no |
| service_specific_routes | Routes per service | `map(list(object))` | `{}` | no |
| enable_dns_support | VPC DNS support | `bool` | `true` | no |
| enable_dns_hostnames | VPC DNS hostnames | `bool` | `true` | no |
| enable_flow_logs | Enable VPC Flow Logs | `bool` | `true` | no |
| flow_logs_traffic_type | ALL, ACCEPT or REJECT | `string` | `"ALL"` | no |
| flow_logs_retention_days | Log retention (days) | `number` | `30` | no |
| flow_logs_kms_key_id | KMS key for the log group | `string` | `null` | no |
| flow_logs_role_arn | External flow logs role | `string` | `null` (in-module) | no |
| common_tags | Tags for all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id / vpc_arn / vpc_name / vpc_cidr_block | VPC identity |
| availability_zones | AZs used |
| private_subnet_ids_by_service | Subnet IDs grouped by service |
| private_subnet_ids_all | All subnet IDs |
| private_subnet_cidrs_by_service | Subnet CIDRs by service |
| private_route_table_ids | Route table IDs per service |
| subnet_capacity_info | Capacity summary (used/remaining) |
| flow_log_id / flow_logs_log_group_name / flow_logs_role_arn | Flow logs details |
<!-- END_TF_DOCS -->

## License

MIT. See [LICENSE](./LICENSE).
