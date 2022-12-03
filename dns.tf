locals {
  dns_zone_name                = split("/", var.dns_zone_id).8
  dns_zone_resource_group_name = split("/", var.dns_zone_id).4
}

data "azurerm_dns_zone" "main" {
  name                = local.dns_zone_name
  resource_group_name = local.dns_zone_resource_group_name
}

resource "azurerm_dns_a_record" "gateway" {
  name                = split(".", local.hostnames.gateway).0
  zone_name           = data.azurerm_dns_zone.main.name
  resource_group_name = data.azurerm_dns_zone.main.resource_group_name
  ttl                 = 3600
  target_resource_id  = azurerm_public_ip.gateway.id
}

resource "azurerm_dns_cname_record" "frontdoor" {
  name                = "${local.project}-fd"
  zone_name           = data.azurerm_dns_zone.main.name
  resource_group_name = data.azurerm_dns_zone.main.resource_group_name
  ttl                 = 3600
  record              = azurerm_cdn_frontdoor_endpoint.main.host_name
}

resource "azurerm_dns_txt_record" "frontdoor" {
  name                = join(".", ["_dnsauth", "${local.project}-fd"])
  zone_name           = data.azurerm_dns_zone.main.name
  resource_group_name = data.azurerm_dns_zone.main.resource_group_name
  ttl                 = 3600

  record {
    value = azurerm_cdn_frontdoor_custom_domain.main.validation_token
  }
}

resource "azurerm_dns_cname_record" "api" {
  name                = split(".", local.hostnames.api).0
  zone_name           = data.azurerm_dns_zone.main.name
  resource_group_name = data.azurerm_dns_zone.main.resource_group_name
  ttl                 = 3600
  record              = "${azurerm_api_management.main.name}.azure-api.net"
}
