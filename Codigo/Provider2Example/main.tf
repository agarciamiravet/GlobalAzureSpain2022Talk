#&nbsp;since these variables are re-used - a locals block makes this more maintainable
locals {
  backend_address_pool_name      = "${azurerm_virtual_network.core.name}-beap"
  frontend_port_name             = "${azurerm_virtual_network.core.name}-feport"
  frontend_ip_configuration_name = "${azurerm_virtual_network.core.name}-feip"
  http_setting_name              = "${azurerm_virtual_network.core.name}-be-htst"
  http_setting_name2             = "${azurerm_virtual_network.core.name}-be-htst-2"
  listener_name                  = "${azurerm_virtual_network.core.name}-httplstn"
  request_routing_rule_name      = "${azurerm_virtual_network.core.name}-rqrt"
  redirect_configuration_name    = "${azurerm_virtual_network.core.name}-rdrcfg"
}

################################################################################
## Resources groups delete
################################################################################

#En la versión 2.0 del provider sino se especifica en features:
# resource_group {
    #  prevent_deletion_if_contains_resources = true
    #}
# De manera silenciosa se borran todos los recursos dentro del resource group
resource "azurerm_resource_group" "rg-with-services" {
  name     = "rg-with-services"
  location = "West Europe"
}


########################################################################################
## Application gateway nested items change throws changes in terraform plan
########################################################################################
resource "azurerm_resource_group" "core" {
  name     = "rg-resources-provider-v2"
  location = "West Europe"
}


resource "azurerm_application_gateway" "network" {
  name                = "example-appgateway"
  resource_group_name = azurerm_resource_group.core.name
  location            = azurerm_resource_group.core.location

  sku {
    name     = "Standard_Small"
    tier     = "Standard"
    capacity = 1
  }

  gateway_ip_configuration {
    name      = "my-gateway-ip-configuration"
    subnet_id = azurerm_subnet.frontend.id
  }

  frontend_port {
    name = local.frontend_port_name
    port = 80
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.core.id
  }

  backend_address_pool {
    name = local.backend_address_pool_name
  }

    backend_http_settings {
    name                  = local.http_setting_name2
    cookie_based_affinity = "Disabled"
    path                  = "/path3/"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 120
  }
  
    backend_http_settings {
    name                  = local.http_setting_name
    cookie_based_affinity = "Disabled"
    path                  = "/path1/"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }



  http_listener {
    name                           = local.listener_name
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = local.request_routing_rule_name
    rule_type                  = "Basic"
    http_listener_name         = local.listener_name
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.http_setting_name
  }
}

resource "azurerm_virtual_network" "core" {
  name                = "example-network"
  resource_group_name = azurerm_resource_group.core.name
  location            = azurerm_resource_group.core.location
  address_space       = ["10.254.0.0/16"]
}

resource "azurerm_subnet" "frontend" {
  name                 = "frontend"
  resource_group_name  = azurerm_resource_group.core.name
  virtual_network_name = azurerm_virtual_network.core.name
  address_prefixes     = ["10.254.0.0/24"]
}

resource "azurerm_subnet" "backend" {
  name                 = "backend"
  resource_group_name  = azurerm_resource_group.core.name
  virtual_network_name = azurerm_virtual_network.core.name
  address_prefixes     = ["10.254.2.0/24"]
}

resource "azurerm_public_ip" "core" {
  name                = "example-pip"
  resource_group_name = azurerm_resource_group.core.name
  location            = azurerm_resource_group.core.location
  allocation_method   = "Dynamic"
}

####################################################################################
# Soft Delete for Key Vault
####################################################################################
resource "azurerm_key_vault" "core" {
  name                        = "kv-providertwo"
  location                    = azurerm_resource_group.core.location
  resource_group_name         = azurerm_resource_group.core.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"

}