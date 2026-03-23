# We need to migrate to use the OpenBao provider, once the provider is ready.
# https://github.com/openbao/openbao/issues/339
terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5"
    }
  }
}
