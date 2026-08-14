# Complete example

Creates a private VPC (10.20.0.0/16) segmented into three services —
`eks`, `databases`, `messaging` — each with 3 private /21 subnets (one
per AZ) and its own route table. Flow logs are enabled by default.

Optionally routes all egress through a Transit Gateway:

```bash
terraform apply -var "transit_gateway_id=tgw-xxxx"
```
