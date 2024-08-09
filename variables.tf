variable "vpc_cidr_allow_list" {
  description = "Modified RFC 1918 CIDR with AWS minimum /16 prefixes"
  type        = list(string)

  default = [
    "10.0.0.0/16",
    "172.31.0.0/16",
    "192.168.0.0/16"
  ]
}

variable "vpc_name" {
  description = "Name of the VPC used for Resource tags"
  type        = string
  default     = ""
}

# -- VPC Defaults
variable "enable_ipv6" {
  description = "Do you want to enable IPv6 on the VPC?"
  type        = bool
  default     = true
}

# -- Public Subnet Defaults
variable "public_subnet_auto_assign_public_ipv4" {
  description = "Do you want to enable public subnet IPv6?"
  type        = bool
  default     = false
}

variable "public_subnet_enable_ipv6" {
  description = "Do you want to enable public subnet IPv6?"
  type        = bool
  default     = false
}

variable "public_subnet_ipv6_only" {
  description = "Do you want to make public subnet IPv6-only?"
  type        = bool
  default     = false
}

variable "public_subnet_auto_assign_ipv6" {
  description = "Do you want to automatically assign IPv6 address to network interfaces?"
  type        = bool
  default     = true
}

variable "public_subnet_enable_dns64" {
  description = "Do you want to enable DNS64 in public subnet?"
  type        = bool
  default     = true
}

# -- Private Subnet Defaults
variable "private_subnet_enable_ipv6" {
  description = "Do you want to enable private subnet IPv6?"
  type        = bool
  default     = false
}

variable "private_subnet_ipv6_only" {
  description = "Do you want to make private subnet IPv6-only?"
  type        = bool
  default     = false
}

variable "private_subnet_auto_assign_ipv6" {
  description = "Do you want to automatically assign IPv6 address to network interfaces?"
  type        = bool
  default     = true
}

variable "private_subnet_enable_dns64" {
  description = "Do you want to enable DNS64?"
  type        = bool
  default     = true
}

# -- IPv6 Native Subnet Defaults
variable "enable_ipv6_only_subnets" {
  description = "Do you want IPv6-only subnet?"
  type        = bool
  default     = true
}

