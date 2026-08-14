# Complete example

Creates a private VPC (10.20.0.0/16) segmented into three services —
`eks`, `databases`, `messaging` — each with 3 private /21 subnets (one per
AZ) and its own route table. Flow logs are enabled by default.

Values live in [`terraform.tfvars`](./terraform.tfvars); uncomment
`transit_gateway_id` there to route all egress through a Transit Gateway.

## Usage

```bash
terraform init
terraform plan
terraform apply
```
