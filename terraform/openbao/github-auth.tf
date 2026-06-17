resource "vault_jwt_auth_backend" "github" {
  path               = "github"
  oidc_discovery_url = "https://token.actions.githubusercontent.com"
  bound_issuer       = "https://token.actions.githubusercontent.com"
}


resource "vault_jwt_auth_backend_role" "github" {
  role_type         = "jwt"
  backend           = vault_jwt_auth_backend.github.path
  role_name         = "tillycode"
  user_claim        = "repository"
  bound_audiences   = ["https://github.com/tillycode"]
  bound_claims_type = "glob"
  bound_claims = {
    "sub" : "repo:tillycode/*"
  }
}

resource "vault_identity_entity" "github_actions_tillycode_homelab_v2" {
  name     = "github-actions:tillycode/homelab-v2"
  policies = ["github-actions:tillycode/homelab-v2"]
}

resource "vault_identity_entity_alias" "github_actions_tillycode_homelab_v2" {
  name           = "tillycode/homelab-v2"
  mount_accessor = vault_jwt_auth_backend.github.accessor
  canonical_id   = vault_identity_entity.github_actions_tillycode_homelab_v2.id
}

resource "vault_policy" "github_actions_tillycode_homelab_v2" {
  name   = "github-actions:tillycode/homelab-v2"
  policy = <<EOT
  path "github/token/homelab-action" {
    capabilities = ["read"]
  }
  EOT
}
