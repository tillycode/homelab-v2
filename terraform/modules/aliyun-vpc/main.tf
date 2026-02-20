resource "alicloud_vpc" "this" {
  vpc_name    = var.vpc_name
  cidr_block  = var.vpc_cidr
  enable_ipv6 = var.vpc_enable_ipv6
  description = var.vpc_description
}

locals {
  vswitches = {
    for vswitch in var.vswitches :
    "${vswitch.cidr}" => vswitch
  }
}

resource "alicloud_vswitch" "this" {
  for_each             = local.vswitches
  vpc_id               = alicloud_vpc.this.id
  cidr_block           = each.value.cidr
  zone_id              = each.value.zone_id
  enable_ipv6          = each.value.enable_ipv6
  ipv6_cidr_block_mask = each.value.ipv6_cidr_block_mask
  vswitch_name         = each.value.name
  description          = each.value.description
}
