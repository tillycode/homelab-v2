
resource "vault_kubernetes_auth_backend_role" "ai" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "ai"
  bound_service_account_namespaces = ["virtual-machines"]
  bound_service_account_names      = ["ai"]
  // We may use ContainerPath volume and webhook to use a dedicated audience.
  // This might be viable when we deploys a policy enforcement webhook.
  // For now, we'll use the default audience and try not directly use the K8s token.
  audience          = "https://kubernetes.default.svc.hasee.internal"
  alias_name_source = "serviceaccount_name"
}

resource "vault_identity_entity" "ai" {
  name     = "virtual-machines/ai"
  policies = ["virtual-machines/ai"]
}

resource "vault_identity_entity_alias" "ai" {
  name           = "virtual-machines/ai"
  mount_accessor = vault_auth_backend.kubernetes.accessor
  canonical_id   = vault_identity_entity.ai.id
}

# APP ID: 3106928
# Installation ID: 116832039
#
#     bao plugin register -sha256=24b0e060bb13f500ad17a1081fa78cff7aec3ae36562ce2c4e52c38e858a806a secret vault-plugin-secrets-github
#     bao secrets enable -path=github -plugin-name=github plugin
#     bao write /github/config app_id=3106928 prv_key=@tillycode-vault.2026-03-16.private-key.pem
#     bao write /github/permissionset/ai installation_id=116832039 permissions=pull_requests=write permissions=actions=write permissions=workflows=write permissions=contents=write
resource "vault_policy" "ai" {
  name   = "virtual-machines/ai"
  policy = <<-EOF
    path "github/token/ai" {
      capabilities = ["read"]
    }
  EOF
}
