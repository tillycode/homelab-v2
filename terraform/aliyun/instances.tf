## -----------------------------------------------------------------------------
## HGH0
## -----------------------------------------------------------------------------
module "hgh0_security_group" {
  source = "../modules/aliyun-security-group"

  name        = "hgh0-sg"
  description = "hgh0 security group"
  vpc_id      = module.hgh_vpc.vpc_id

  ingress_rules = [
    {
      protocol = "icmp"
      cidrs    = ["0.0.0.0/0"]
      ports    = [-1]
    },
    {
      protocol = "tcp"
      cidrs    = ["0.0.0.0/0", "::/0"]
      ports = [
        22,  # SSH
        80,  # HTTP
        443, # HTTPS
      ]
    },
    {
      protocol = "udp"
      cidrs    = ["0.0.0.0/0", "::/0"]
      ports = [
        51820, # Wireguard
      ]
    }
  ]
}

resource "alicloud_instance" "hgh0" {
  instance_name = "hgh0"

  instance_type   = "ecs.t6-c1m4.xlarge"
  image_id        = "ubuntu_22_04_uefi_x64_20G_alibase_20230515.vhd"
  security_groups = [module.hgh0_security_group.security_group_id]
  vswitch_id      = module.hgh_vpc.vswitch_ids[0]

  lifecycle {
    prevent_destroy = true
  }
}

resource "alicloud_eip_address" "hgh0" {
  internet_charge_type = "PayByTraffic"
  payment_type         = "PayAsYouGo"
  bandwidth            = 200
}

resource "alicloud_eip_association" "hgh0" {
  allocation_id = alicloud_eip_address.hgh0.id
  instance_type = "EcsInstance"
  instance_id   = alicloud_instance.hgh0.id
}


data "alicloud_vpc_ipv6_addresses" "hgh0" {
  associated_instance_id = alicloud_instance.hgh0.id
  status                 = "Available"
}

resource "alicloud_vpc_ipv6_internet_bandwidth" "hgh0" {
  ipv6_address_id      = data.alicloud_vpc_ipv6_addresses.hgh0.addresses.0.id
  ipv6_gateway_id      = alicloud_vpc_ipv6_gateway.hgh.id
  internet_charge_type = "PayByTraffic"
  bandwidth            = 1000
}
