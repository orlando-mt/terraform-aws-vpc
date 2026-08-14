variable "name_prefix" {
  description = "Prefix used to name all resources (e.g. the project or platform name)"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. dev, qa, prod)"
  type        = string
}

# --- Network ---------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid CIDR block."
  }
}

variable "subnet_newbits" {
  description = "Additional bits used to carve subnets from the VPC CIDR (e.g. /16 VPC + 5 newbits = /21 subnets)"
  type        = number
  default     = 5
}

variable "az_count" {
  description = "Number of availability zones to spread each service across"
  type        = number
  default     = 3

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 4
    error_message = "az_count must be between 2 and 4."
  }
}

# --- Services --------------------------------------------------------------

variable "services" {
  description = "List of services; each gets one private subnet per AZ and its own route table"
  type = list(object({
    name = string
    tags = optional(map(string), {})
  }))

  validation {
    condition     = length(var.services) > 0
    error_message = "At least one service is required."
  }

  validation {
    condition     = length(var.services) == length(distinct([for s in var.services : s.name]))
    error_message = "Service names must be unique."
  }

  validation {
    condition     = length(var.services) * var.az_count <= pow(2, var.subnet_newbits)
    error_message = "Not enough subnet space: services * az_count exceeds 2^subnet_newbits. Increase subnet_newbits or reduce services."
  }
}

# --- Routing ---------------------------------------------------------------

variable "custom_routes" {
  description = "Routes added to ALL service route tables (Transit Gateway, peering, NAT, IGW)"
  type = list(object({
    cidr_block                = string
    vpc_peering_connection_id = optional(string)
    transit_gateway_id        = optional(string)
    nat_gateway_id            = optional(string)
    gateway_id                = optional(string)
  }))
  default = []
}

variable "service_specific_routes" {
  description = "Additional routes per service (map keyed by service name)"
  type = map(list(object({
    cidr_block                = string
    vpc_peering_connection_id = optional(string)
    transit_gateway_id        = optional(string)
    nat_gateway_id            = optional(string)
    gateway_id                = optional(string)
  })))
  default = {}
}

# --- DNS -------------------------------------------------------------------

variable "enable_dns_support" {
  description = "Enable DNS support in the VPC"
  type        = bool
  default     = true
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in the VPC"
  type        = bool
  default     = true
}

# --- Flow logs -------------------------------------------------------------

variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs to CloudWatch"
  type        = bool
  default     = true
}

variable "flow_logs_traffic_type" {
  description = "Traffic type to capture: ALL, ACCEPT or REJECT"
  type        = string
  default     = "ALL"

  validation {
    condition     = contains(["ALL", "ACCEPT", "REJECT"], var.flow_logs_traffic_type)
    error_message = "flow_logs_traffic_type must be ALL, ACCEPT or REJECT."
  }
}

variable "flow_logs_retention_days" {
  description = "CloudWatch retention for flow logs in days (set 365+ where compliance requires it)"
  type        = number
  default     = 30
}

variable "flow_logs_kms_key_id" {
  description = "KMS key ARN to encrypt the flow logs log group. The key policy must grant usage to the logs service principal. If null, CloudWatch-managed encryption is used"
  type        = string
  default     = null
}

variable "flow_logs_role_arn" {
  description = "External IAM role ARN for flow logs. If null, the role is created by this module"
  type        = string
  default     = null
}

# --- Tags ------------------------------------------------------------------

variable "common_tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
