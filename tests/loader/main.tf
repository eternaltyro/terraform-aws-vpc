variable "vpc_name" {}
variable "vpc_cidr_allow_list" {}

module "test-vpc" {
  source = "./../.."

  vpc_name            = var.vpc_name
  vpc_cidr_allow_list = var.vpc_cidr_allow_list
}

data "aws_vpc" "test" {
  id = module.test-vpc.vpc_id
}

data "aws_vpc_security_group_rules" "test" {
  filter {
    name   = "group-id"
    values = [module.test-vpc.default_security_group_id]
  }
}
