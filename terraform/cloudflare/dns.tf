variable "zones" {
  type = map(object({
    records = optional(map(object({
      name     = string
      type     = string
      content  = string
      priority = optional(number, null)
    })), {})
  }))
}

module "cloudflare-dns" {
  for_each = var.zones
  source   = "../modules/cloudflare-dns"
  name     = each.key
  records  = each.value.records
}
