variable "vpc_name" {
  type    = string
  default = "test"
}

variable "vpc_cidr_allow_list" {
  type = list(string)
  default = [
    "10.0.0.0/16",
    "172.31.0.0/16",
    "192.168.0.0/16"
  ]
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}
