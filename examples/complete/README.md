# Complete example

Creates a private VPC (10.20.0.0/16) segmented into three services —
`eks`, `databases`, `messaging` — each with 3 private /21 subnets (one per
AZ) and its own route table. Flow logs are enabled by default.

Egress uses the distributed design: public subnets with one NAT gateway per
zone. [`terraform.tfvars`](./terraform.tfvars) also carries the centralised
alternative — no public subnets, and the default route pointed at a Transit
Gateway in a network account.

## Usage

```bash
terraform init
terraform plan
terraform apply
```
