# Common
variables {
  aws_region = "us-east-1"

}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Environment = "Test"
    }
  }
}

provider "aws" {
  alias  = "india"
  region = "ap-south-1"
  default_tags {
    tags = {
      Environment = "Test"
    }
  }
}

# run "setup" {
#   command = apply
#
#   module {
#     source = "./examples"
#   }
# }

run "tests" {
  command = apply

  variables {
    vpc_name = "test"
    vpc_cidr_allow_list = [
      "10.0.0.0/16",
      "172.31.0.0/16",
      "192.168.0.0/16"
    ]
  }

  module {
    source = "./tests/loader"
  }

  assert {
    condition = contains(
      var.vpc_cidr_allow_list,
      data.aws_vpc.test.cidr_block
    )
    error_message = "VPC CIDR block is not valid. Or managed CIDR used."
  }


  assert {
    condition     = length(data.aws_vpc_security_group_rules.test) == 0
    error_message = "CIS Benchmark Compliance failure - default security group contains ingress/egress rules."
  }
}
