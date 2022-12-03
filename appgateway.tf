locals {
  ssl_certificate_name = "default"
}

resource "azurerm_public_ip" "gateway" {
  name                = "pip-${local.resource_suffix}-agw"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 = "Standard"
  public_ip_prefix_id = azurerm_public_ip_prefix.ingress.id
  zones               = ["1", "2", "3"]
}

resource "azurerm_web_application_firewall_policy" "main" {
  name                = "waf-${local.resource_suffix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
    }
  }

  policy_settings {
    enabled                     = true
    mode                        = "Prevention"
    file_upload_limit_in_mb     = 100
    max_request_body_size_in_kb = 128
    request_body_check          = true
  }
}

resource "azurerm_application_gateway" "main" {
  depends_on = [
    azurerm_key_vault_access_policy.identity
  ]
  name                = "agw-${local.resource_suffix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  firewall_policy_id  = azurerm_web_application_firewall_policy.main.id
  enable_http2        = true

  global {
    request_buffering_enabled  = true
    response_buffering_enabled = true
  }

  sku {
    name = "WAF_v2"
    tier = "WAF_v2"
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.main.id]
  }

  autoscale_configuration {
    min_capacity = var.application_gateway_min_capacity
    max_capacity = var.application_gateway_max_capacity
  }

  backend_address_pool {
    name         = "default"
    ip_addresses = [local.load_balancer_ip_address]
  }

  backend_http_settings {
    name                  = "default"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    probe_name            = "default"
  }

  frontend_ip_configuration {
    name                 = "default"
    public_ip_address_id = azurerm_public_ip.gateway.id
  }

  gateway_ip_configuration {
    name      = "default"
    subnet_id = azurerm_subnet.gateway.id
  }

  http_listener {
    name                           = "http"
    frontend_ip_configuration_name = "default"
    frontend_port_name             = "http"
    protocol                       = "Http"
    host_name                      = local.hostnames.gateway
  }

  http_listener {
    name                           = "https"
    frontend_ip_configuration_name = "default"
    frontend_port_name             = "https"
    protocol                       = "Https"
    host_name                      = local.hostnames.gateway
    require_sni                    = true
    ssl_certificate_name           = local.ssl_certificate_name
  }

  frontend_port {
    name = "http"
    port = 80
  }

  frontend_port {
    name = "https"
    port = 443
  }

  request_routing_rule {
    name                        = "http"
    rule_type                   = "Basic"
    http_listener_name          = "http"
    redirect_configuration_name = "default"
    priority                    = 2
  }

  request_routing_rule {
    name                       = "https"
    rule_type                  = "Basic"
    http_listener_name         = "https"
    backend_address_pool_name  = "default"
    backend_http_settings_name = "default"
    priority                   = 1
  }

  probe {
    name                = "default"
    host                = local.load_balancer_ip_address
    interval            = 30
    protocol            = "Http"
    path                = "/healthz"
    timeout             = 3
    unhealthy_threshold = 3
  }

  redirect_configuration {
    name                 = "default"
    include_path         = true
    include_query_string = true
    redirect_type        = "Permanent"
    target_listener_name = "https"
  }

  ssl_certificate {
    key_vault_secret_id = data.azurerm_key_vault_secret.main.versionless_id
    name                = local.ssl_certificate_name
  }
}
