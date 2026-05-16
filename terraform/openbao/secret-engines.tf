resource "vault_identity_oidc" "server" {
  issuer = "https://vault.szp15.com"
}

resource "vault_identity_oidc_key" "key" {
  name      = "key"
  algorithm = "RS256"
}
