resource "vault_plugin" "github" {
  type    = "secret"
  name    = "github"
  command = "vault-plugin-secrets-github"
  version = "2.3.2"
  sha256  = "2ecac28dc0977c5c93d30044eb75b7db9df96e27d5ce6779ae9eeab4d4cda24b"
}

resource "vault_mount" "github" {
  path = "github"
  type = vault_plugin.github.name
}


# APP ID: 3106928
# Installation ID: 116832039
#
#     bao write github/config app_id=3106928 prv_key=@tillycode-vault.2026-03-16.private-key.pem exclude_repository_metadata=true
#
resource "vault_generic_endpoint" "github_homelab_action" {
  path = "github/permissionset/homelab-action"
  data_json = jsonencode({
    installation_id = 116832039
    # create a PR
    permissions = {
      pull_requests = "write"
      contents      = "write"
    }
    # tillycode/homelab-v2
    repository_ids = [1111292990]
  })
  ignore_absent_fields = true
}
