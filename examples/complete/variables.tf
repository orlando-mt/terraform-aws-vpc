variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "transit_gateway_id" {
  description = "Optional Transit Gateway for the default route"
  type        = string
  default     = null
}
