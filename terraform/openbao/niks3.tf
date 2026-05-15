resource "vault_identity_oidc_role" "role" {
  name      = "niks3"
  key       = vault_identity_oidc_key.key.name
  client_id = "https://niks3.szp.io"
  ttl       = 86400
}

resource "vault_identity_oidc_key_allowed_client_id" "role" {
  key_name          = vault_identity_oidc_key.key.name
  allowed_client_id = vault_identity_oidc_role.role.client_id
}
