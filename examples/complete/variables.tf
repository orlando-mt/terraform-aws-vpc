variable "region" {
  description = "AWS region"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "subnet_newbits" {
  description = "Additional bits used to carve subnets"
  type        = number
  default     = 5
}

variable "az_count" {
  description = "Availability zones per service"
  type        = number
  default     = 3
}

variable "services" {
  description = "Services; each gets one private subnet per AZ and its own route table"
  type = list(object({
    name = string
    tags = optional(map(string), {})
  }))
}

variable "create_public_subnets" {
  description = "Create public subnets and an internet gateway"
  type        = bool
  default     = false
}

variable "nat_gateway_mode" {
  description = "none, single or per_az"
  type        = string
  default     = "none"
}

variable "public_subnet_tags" {
  description = "Extra tags for the public subnets"
  type        = map(string)
  default     = {}
}

variable "transit_gateway_id" {
  description = "Optional Transit Gateway for the default route"
  type        = string
  default     = null
}

variable "common_tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
