data "cloudflare_zone" "this" {
  filter = {
    name = var.name
  }
}

resource "cloudflare_dns_record" "this" {
  for_each = var.records
  zone_id  = data.cloudflare_zone.this.zone_id
  name     = each.value.name
  type     = each.value.type
  ttl      = 1
  proxied  = false
  content  = each.value.content
  priority = each.value.priority
}
