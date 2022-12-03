data "azurerm_client_config" "main" {}

data "azuread_client_config" "main" {}

data "azurerm_kubernetes_service_versions" "main" {
  location        = var.location
  include_preview = var.kubernetes_service_versions_include_preview
}

# data "azuread_service_principal" "frontdoor" {
#   display_name = "Microsoft.AzureFrontDoor-Cdn"
# }

data "azurerm_lb" "kubernetes" {
  name                = "kubernetes-internal"
  resource_group_name = azurerm_kubernetes_cluster.main.node_resource_group
}
