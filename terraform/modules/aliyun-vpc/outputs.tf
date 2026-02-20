output "vpc_id" {
  value = alicloud_vpc.this.id
}


output "vswitch_ids" {
  value = [
    for vswitch in var.vswitches :
    alicloud_vswitch.this[vswitch.cidr].id
  ]
}

output "route_table_id" {
  value = alicloud_vpc.this.route_table_id
}
