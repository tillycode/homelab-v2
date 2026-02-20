module "hgh_vpc" {
  source          = "../modules/aliyun-vpc"
  vpc_name        = "hgh-vpc"
  vpc_description = "Hangzhou VPC"
  vpc_cidr        = "10.112.33.0/24"

  vswitches = [
    {
      cidr        = "10.112.33.0/24"
      zone_id     = "cn-hangzhou-h"
      description = "Hangzhou VSwitch"
    }
  ]
}

resource "alicloud_vpc_ipv6_gateway" "hgh" {
  vpc_id = module.hgh_vpc.vpc_id
}
