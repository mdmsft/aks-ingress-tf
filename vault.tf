locals {
  key_vault_name                = split("/", var.ssl_certificate_key_vault_id).8
  key_vault_resource_group_name = split("/", var.ssl_certificate_key_vault_id).4
  key_vault_subscription_id     = split("/", var.ssl_certificate_key_vault_id).2
}

data "azurerm_key_vault" "main" {
  name                = local.key_vault_name
  resource_group_name = local.key_vault_resource_group_name
}

data "azurerm_key_vault_certificate" "main" {
  name         = var.ssl_certificate_name
  key_vault_id = data.azurerm_key_vault.main.id

  depends_on = [
    azurerm_key_vault_access_policy.key_vault_administrator
  ]
}

data "azurerm_key_vault_secret" "main" {
  name         = reverse(split("/", data.azurerm_key_vault_certificate.main.versionless_secret_id)).0
  key_vault_id = data.azurerm_key_vault.main.id

  depends_on = [
    azurerm_key_vault_access_policy.key_vault_administrator
  ]
}

resource "azurerm_key_vault_access_policy" "key_vault_administrator" {
  certificate_permissions = ["Backup", "Create", "Delete", "DeleteIssuers", "Get", "GetIssuers", "Import", "List", "ListIssuers", "ManageContacts", "ManageIssuers", "Purge", "Recover", "Restore", "SetIssuers", "Update"]
  secret_permissions      = ["Backup", "Delete", "Get", "List", "Purge", "Recover", "Restore", "Set"]
  key_permissions         = ["Backup", "Create", "Decrypt", "Delete", "Encrypt", "Get", "Import", "List", "Purge", "Recover", "Restore", "Sign", "UnwrapKey", "Update", "Verify", "WrapKey", "Release", "Rotate", "GetRotationPolicy", "SetRotationPolicy"]
  key_vault_id            = data.azurerm_key_vault.main.id
  object_id               = data.azurerm_client_config.main.object_id
  tenant_id               = data.azurerm_client_config.main.tenant_id
}

resource "azurerm_key_vault_access_policy" "frontdoor" {
  certificate_permissions = ["Get", "List"]
  secret_permissions      = ["Get", "List"]
  key_vault_id            = data.azurerm_key_vault.main.id
  object_id               = "4dbab725-22a4-44d5-ad44-c267ca38a954" //data.azuread_service_principal.frontdoor.object_id
  tenant_id               = data.azurerm_client_config.main.tenant_id
}

resource "azurerm_key_vault_access_policy" "identity" {
  secret_permissions = ["Get", "List"]
  key_vault_id       = data.azurerm_key_vault.main.id
  object_id          = azurerm_user_assigned_identity.main.principal_id
  tenant_id          = data.azurerm_client_config.main.tenant_id
}
