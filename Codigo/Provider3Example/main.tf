#&nbsp;since these variables are re-used - a locals block makes this more maintainable
locals {
  backend_address_pool_name      = "${azurerm_virtual_network.core.name}-beap"
  frontend_port_name             = "${azurerm_virtual_network.core.name}-feport"
  frontend_ip_configuration_name = "${azurerm_virtual_network.core.name}-feip"
  http_setting_name              = "${azurerm_virtual_network.core.name}-be-htst"
  http_setting_name2             = "${azurerm_virtual_network.core.name}-be-htst2"
  listener_name                  = "${azurerm_virtual_network.core.name}-httplstn"
  request_routing_rule_name      = "${azurerm_virtual_network.core.name}-rqrt"
  redirect_configuration_name    = "${azurerm_virtual_network.core.name}-rdrcfg"
}

#En la versión 3 del provider sino se especifica en features:
# De manera predeterminada no se un resource group
#si existen recursos dentro
# Para deshabilitar esto debriamos especificar en features:
#   #  resource_group {
    #  prevent_deletion_if_contains_resources = true
    #}
resource "azurerm_resource_group" "rg-with-services" {
  name     = "rg-with-services"
  location = "West Europe"
}

resource "azurerm_resource_group" "core" {
  name     = "example-resources-v3"
  location = "West Europe"
}

########################################################################################
## Application gateway nested items change not changes anything. All it´s ok :)
########################################################################################
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

      backend_http_settings {
    name                  = local.http_setting_name2
    cookie_based_affinity = "Disabled"
    path                  = "/path2/"
    port                  = 443
    protocol              = "Https"
    request_timeout       = 60
  }

  request_routing_rule {
    name                       = local.request_routing_rule_name
    rule_type                  = "Basic"
    http_listener_name         = local.listener_name
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.http_setting_name
  }
}

####################################################################################
# Soft Delete for Key Vault
####################################################################################
resource "azurerm_key_vault" "core" {
  name                        = "kv-providerthree"
  location                    = azurerm_resource_group.core.location
  resource_group_name         = azurerm_resource_group.core.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"

}

############################################################################################
#### Sticky settings 
############################################################################################
resource "azurerm_service_plan" "core" {
  name                = "plan-global-azure-spain-2022-sticky"
  resource_group_name = azurerm_resource_group.core.name
  location            = "West Europe"
  os_type             = "Linux"
  sku_name            = "P1v2"
}

resource "azurerm_windows_web_app" "core" {
  name                = "app-gas2022-terraform-talk-sticky"
  resource_group_name = azurerm_resource_group.core.name
  location            = azurerm_service_plan.core.location
  service_plan_id     = azurerm_service_plan.core.id

  site_config {}

    app_settings = {
    foo    = "bar"
    secret = "sauce"
    third  = "degree"
  }
  connection_string {
    name  = "First"
    value = "first-connection-string"
    type  = "Custom"
  }
  connection_string {
    name  = "Second"
    value = "some-postgresql-connection-string"
    type  = "PostgreSQL"
  }
  connection_string {
    name  = "Third"
    value = "some-postgresql-connection-string"
    type  = "PostgreSQL"
  }

    sticky_settings {
    app_setting_names       = ["foo", "secret", "third"]
    connection_string_names = ["First", "Second", "Third"]
  }
}

resource "azurerm_windows_web_app_slot" "core" {
  name           = "app-gas2022-terraform-talk-sticky-slot"
  app_service_id = azurerm_windows_web_app.core.id

  site_config {}

      app_settings = {
    foo    = "bar-slot"
    secret = "sauce-slot"
    third  = "degree-slot"
  }
  connection_string {
    name  = "First"
    value = "first-connection-string-slot"
    type  = "Custom"
  }
  connection_string {
    name  = "Second"
    value = "some-postgresql-connection-string-slot"
    type  = "PostgreSQL"
  }
  connection_string {
    name  = "Third"
    value = "some-postgresql-connection-string-slot"
    type  = "PostgreSQL"
  }
}


#resource "azurerm_windows_web_app" "test" {
#  name                = "acctestWA-%d"
#  location            = azurerm_resource_group.test.location
#  resource_group_name = azurerm_resource_group.test.name
#  service_plan_id     = azurerm_service_plan.test.id
#  site_config {}
#  app_settings = {
#    foo    = "bar"
#    secret = "sauce"
#    third  = "degree"
#  }
#  connection_string {
#    name  = "First"
#    value = "first-connection-string"
#    type  = "Custom"
#  }
#  connection_string {
#    name  = "Second"
#    value = "some-postgresql-connection-string"
#    type  = "PostgreSQL"
#  }
#  connection_string {
#    name  = "Third"
#    value = "some-postgresql-connection-string"
#    type  = "PostgreSQL"
#  }
#  sticky_settings {
#    app_setting_names       = ["foo", "secret", "third"]
#    connection_string_names = ["First", "Second", "Third"]
#  }
#}


#Sticky settings before version 3.4.0 of provider
#resource "azurerm_template_deployment" "dataexchangewebappconfig" {
#  name                = "stickysettingswebappconfig"
#  resource_group_name = var.resource_group_name
#  deployment_mode     = "Incremental"
#
#  template_body = <<DEPLOY
#{
#  "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
#  "contentVersion": "1.0.0.0",
#  "parameters": {
#      "stickyAppSettingNames": {
#        "type": "String"
#      },
#      "webAppName": {
#          "type": "String"
#      }
#  },
#  "variables": {
#    "appSettingNames": "[split(parameters('stickyAppSettingNames'),',')]"
#  },
#  "resources": [
#      {
#        "type": "Microsoft.Web/sites/config",
#        "name": "[concat(parameters('webAppName'),'/slotconfignames')]",
#        "apiVersion": "2015-08-01",
#        "properties": {
#          "appSettingNames": "[variables('appSettingNames')]"
#        }
#      }
#  ],
#  "outputs": {
#    "outWebAppName": {
#      "type": "string",
#      "value": "[parameters('webAppName')]"
#    }
#  }
#}
#DEPLOY
#
#  parameters = {
#    "webAppName"            = azurerm_app_service.example.name
#    "stickyAppSettingNames" = "APPINSIGHTS_INSTRUMENTATIONKEY,CustomAppSetting01,CustomAppSetting02"
#  }
#
#  depends_on = [
#    azurerm_app_service.app-dataexchange,
#    azurerm_app_service_slot.blue
#  ]
#}