resource "azurerm_cdn_frontdoor_profile" "main" {
  name                     = "cdnp-${local.resource_suffix}"
  resource_group_name      = azurerm_resource_group.main.name
  sku_name                 = "Premium_AzureFrontDoor"
  response_timeout_seconds = 16
}

resource "azurerm_cdn_frontdoor_secret" "main" {
  name                     = local.ssl_certificate_name
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id

  secret {
    customer_certificate {
      key_vault_certificate_id = data.azurerm_key_vault_certificate.main.versionless_id
    }
  }
}

resource "azurerm_cdn_frontdoor_firewall_policy" "main" {
  name                = replace("waf-${local.resource_suffix}", "-", "")
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = azurerm_cdn_frontdoor_profile.main.sku_name
  mode                = "Prevention"

  managed_rule {
    type    = "Microsoft_DefaultRuleSet"
    version = "2.1"
    action  = "Block"
  }
}

resource "azurerm_cdn_frontdoor_custom_domain" "main" {
  name                     = local.project
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id
  dns_zone_id              = data.azurerm_dns_zone.main.id
  host_name                = local.hostnames.frontdoor

  tls {
    certificate_type        = "CustomerCertificate"
    cdn_frontdoor_secret_id = azurerm_cdn_frontdoor_secret.main.id
  }
}

resource "azurerm_cdn_frontdoor_security_policy" "main" {
  name                     = "default"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id

  security_policies {
    firewall {
      cdn_frontdoor_firewall_policy_id = azurerm_cdn_frontdoor_firewall_policy.main.id

      association {
        patterns_to_match = ["/*"]

        domain {
          cdn_frontdoor_domain_id = azurerm_cdn_frontdoor_custom_domain.main.id
        }
      }
    }
  }
}

resource "azurerm_cdn_frontdoor_endpoint" "main" {
  name                     = local.resource_suffix
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id
}

resource "azurerm_cdn_frontdoor_origin_group" "main" {
  name                     = "default"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id
  session_affinity_enabled = false

  health_probe {
    protocol            = "Http"
    interval_in_seconds = 5
    request_type        = "HEAD"
    path                = "/healthz"
  }

  load_balancing {}
}

resource "azurerm_cdn_frontdoor_origin" "main" {
  name                           = "nginx"
  cdn_frontdoor_origin_group_id  = azurerm_cdn_frontdoor_origin_group.main.id
  host_name                      = local.load_balancer_ip_address
  certificate_name_check_enabled = true
  enabled                        = true
  origin_host_header             = local.hostnames.frontdoor

  private_link {
    location               = data.azurerm_lb.kubernetes.location
    private_link_target_id = azurerm_private_link_service.main.id
  }

  depends_on = [
    azurerm_private_link_service.main
  ]
}

resource "azurerm_cdn_frontdoor_route" "main" {
  name                            = "default"
  cdn_frontdoor_endpoint_id       = azurerm_cdn_frontdoor_endpoint.main.id
  cdn_frontdoor_origin_group_id   = azurerm_cdn_frontdoor_origin_group.main.id
  cdn_frontdoor_origin_ids        = [azurerm_cdn_frontdoor_origin.main.id]
  cdn_frontdoor_custom_domain_ids = [azurerm_cdn_frontdoor_custom_domain.main.id]
  forwarding_protocol             = "HttpOnly"
  patterns_to_match               = ["/*"]
  supported_protocols             = ["Http", "Https"]
  https_redirect_enabled          = true
  link_to_default_domain          = false
}

