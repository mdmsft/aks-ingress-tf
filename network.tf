resource "azurerm_virtual_network" "main" {
  name                = "vnet-${local.resource_suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = var.address_space
}

resource "azurerm_subnet" "cluster" {
  name                 = "snet-aks"
  virtual_network_name = azurerm_virtual_network.main.name
  resource_group_name  = azurerm_resource_group.main.name
  address_prefixes     = [var.address_space.0]
}

resource "azurerm_subnet" "gateway" {
  name                 = "snet-agw"
  virtual_network_name = azurerm_virtual_network.main.name
  resource_group_name  = azurerm_resource_group.main.name
  address_prefixes     = [var.address_space.1]
}

resource "azurerm_subnet" "link" {
  name                                          = "snet-link"
  resource_group_name                           = azurerm_resource_group.main.name
  virtual_network_name                          = azurerm_virtual_network.main.name
  address_prefixes                              = [var.address_space.2]
  private_link_service_network_policies_enabled = false
}

resource "azurerm_subnet" "api" {
  name                 = "snet-apim"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.address_space.3]
}

resource "azurerm_subnet" "endpoint" {
  name                                      = "snet-pe"
  resource_group_name                       = azurerm_resource_group.main.name
  virtual_network_name                      = azurerm_virtual_network.main.name
  address_prefixes                          = [var.address_space.4]
  private_endpoint_network_policies_enabled = false
}

resource "azurerm_network_security_group" "cluster" {
  name                = "nsg-${local.resource_suffix}-aks"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "AllowInternetHttpIn"
    priority                   = 100
    protocol                   = "Tcp"
    access                     = "Allow"
    direction                  = "Inbound"
    source_address_prefix      = "Internet"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_ranges    = ["80", "443"]
  }

  security_rule {
    name                       = "AllowAzureLoadBalancerIn"
    priority                   = 200
    protocol                   = "Tcp"
    access                     = "Allow"
    direction                  = "Inbound"
    source_address_prefix      = "AzureLoadBalancer"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_ranges    = ["80", "443"]
  }
}

resource "azurerm_network_security_group" "gateway" {
  name                = "nsg-${local.resource_suffix}-agw"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                         = "AllowInternetIn"
    priority                     = 100
    direction                    = "Inbound"
    access                       = "Allow"
    protocol                     = "Tcp"
    source_port_range            = "*"
    destination_port_ranges      = ["80", "443"]
    source_address_prefix        = "Internet"
    destination_address_prefixes = azurerm_subnet.gateway.address_prefixes
  }

  security_rule {
    name                       = "AllowGatewayManagerIn"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "65200-65535"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowAzureLoadBalancerIn"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "link" {
  name                = "nsg-${local.resource_suffix}-pls"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_network_security_group" "api" {
  name                = "nsg-${local.resource_suffix}-apim"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "AllowInternetIn"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443"]
    source_address_prefix      = "Internet"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "AllowApiManagementIn"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3443"
    source_address_prefix      = "ApiManagement"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "AllowAzureLoadBalancerIn"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6390"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "AllowStorageOut"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "Storage"
  }

  security_rule {
    name                       = "AllowSqlOut"
    priority                   = 200
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "1433"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "SQL"
  }

  security_rule {
    name                       = "AllowAzureKeyVaultOut"
    priority                   = 300
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "AzureKeyVault"
  }
}

resource "azurerm_subnet_network_security_group_association" "cluster" {
  network_security_group_id = azurerm_network_security_group.cluster.id
  subnet_id                 = azurerm_subnet.cluster.id
}

resource "azurerm_subnet_network_security_group_association" "gateway" {
  network_security_group_id = azurerm_network_security_group.gateway.id
  subnet_id                 = azurerm_subnet.gateway.id
}

resource "azurerm_subnet_network_security_group_association" "link" {
  network_security_group_id = azurerm_network_security_group.link.id
  subnet_id                 = azurerm_subnet.link.id
}

resource "azurerm_subnet_network_security_group_association" "api" {
  network_security_group_id = azurerm_network_security_group.api.id
  subnet_id                 = azurerm_subnet.api.id
}

resource "azurerm_public_ip_prefix" "ingress" {
  name                = "ippre-${local.resource_suffix}-ing"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  prefix_length       = 30
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
}

resource "azurerm_public_ip_prefix" "cluster" {
  name                = "ippre-${local.resource_suffix}-aks"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  prefix_length       = var.nat_gateway_public_ip_prefix_length
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
}

resource "azurerm_nat_gateway" "cluster" {
  name                    = "ng-${local.resource_suffix}-aks"
  location                = azurerm_resource_group.main.location
  resource_group_name     = azurerm_resource_group.main.name
  idle_timeout_in_minutes = 4
  sku_name                = "Standard"
}

resource "azurerm_nat_gateway_public_ip_prefix_association" "cluster" {
  nat_gateway_id      = azurerm_nat_gateway.cluster.id
  public_ip_prefix_id = azurerm_public_ip_prefix.cluster.id
}

resource "azurerm_subnet_nat_gateway_association" "cluster" {
  nat_gateway_id = azurerm_nat_gateway.cluster.id
  subnet_id      = azurerm_subnet.cluster.id
}

resource "azurerm_private_link_service" "main" {
  name                                        = "pls-${local.resource_suffix}"
  resource_group_name                         = azurerm_resource_group.main.name
  location                                    = azurerm_resource_group.main.location
  visibility_subscription_ids                 = [data.azurerm_client_config.main.subscription_id]
  load_balancer_frontend_ip_configuration_ids = [data.azurerm_lb.kubernetes.frontend_ip_configuration.0.id]

  nat_ip_configuration {
    name                       = "primary"
    private_ip_address         = local.private_link_nat_ip_address
    private_ip_address_version = "IPv4"
    subnet_id                  = azurerm_subnet.link.id
    primary                    = true
  }
}

resource "azurerm_private_endpoint" "main" {
  name                          = "pe-${local.resource_suffix}"
  location                      = azurerm_resource_group.main.location
  resource_group_name           = azurerm_resource_group.main.name
  subnet_id                     = azurerm_subnet.endpoint.id
  custom_network_interface_name = "nic-${local.resource_suffix}-pe"

  private_service_connection {
    name                           = "default"
    private_connection_resource_id = azurerm_private_link_service.main.id
    is_manual_connection           = false
  }

  depends_on = [
    azurerm_private_link_service.main
  ]
}
