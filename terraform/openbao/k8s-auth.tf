resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"

  tune {
    default_lease_ttl = "1h"
    max_lease_ttl     = "24h"
  }
}

resource "vault_kubernetes_auth_backend_config" "this" {
  backend         = vault_auth_backend.kubernetes.path
  kubernetes_host = "https://kubernetes.default.svc.hasee.internal"
}
