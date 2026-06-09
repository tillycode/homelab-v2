resource "vault_jwt_auth_backend" "github" {
  path               = "github"
  oidc_discovery_url = "https://token.actions.githubusercontent.com"
  bound_issuer       = "https://token.actions.githubusercontent.com"
}


resource "vault_jwt_auth_backend_role" "github" {
  role_type         = "jwt"
  backend           = vault_jwt_auth_backend.github.path
  role_name         = "tillycode"
  user_claim        = "sub"
  bound_audiences   = ["https://github.com/tillycode"]
  bound_claims_type = "glob"
  bound_claims = {
    "sub" : "repo:tillycode/*"
  }
}
