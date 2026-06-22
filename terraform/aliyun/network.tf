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

resource "alicloud_route_entry" "hgh_svc" {
  route_table_id        = module.hgh_vpc.route_table_id
  destination_cidrblock = "10.112.32.0/24"
  nexthop_type          = "Instance"
  nexthop_id            = alicloud_instance.hgh0.id
}
