module "vpc" {
  // source = "git::https://gitlab.com/eternaltyro/terraform-aws-vpc.git"
  source = "./.."

  vpc_cidr_allow_list = [
    "10.0.0.0/16",
    "172.31.0.0/16",
    "192.168.0.0/16"
  ]
}
