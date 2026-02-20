resource "alicloud_security_group" "this" {
  security_group_name = var.name
  vpc_id              = var.vpc_id
  description         = var.description
}

locals {
  ingress_rules = {
    for rule in flatten([
      for rule in var.ingress_rules : [
        for cidr in rule.cidrs : concat([
          for port in rule.ports : {
            protocol  = rule.protocol
            from_port = port
            to_port   = port
            cidr      = cidr
          }
          ], [
          for port in rule.port_ranges : {
            protocol  = rule.protocol
            from_port = port[0]
            to_port   = port[1]
            cidr      = cidr
          }
        ])
      ]
    ]) :
    "${rule.protocol}:${rule.cidr}:${rule.from_port}:${rule.to_port}" => rule
  }
}

resource "alicloud_security_group_rule" "this" {
  for_each          = local.ingress_rules
  type              = "ingress"
  ip_protocol       = each.value.protocol
  port_range        = "${each.value.from_port}/${each.value.to_port}"
  cidr_ip           = strcontains(each.value.cidr, ".") ? each.value.cidr : null
  ipv6_cidr_ip      = strcontains(each.value.cidr, ":") ? each.value.cidr : null
  nic_type          = "intranet"
  security_group_id = alicloud_security_group.this.id
}
