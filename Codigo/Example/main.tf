#####################################################################################################################
## Naming of resources using best practices for Microsoft
## https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations
#####################################################################################################################

resource "azurerm_resource_group" "core" {
  name     = "rg-global-azure-spain-2022"
  location = var.location
}

resource "azurerm_service_plan" "core" {
  name                = "plan-global-azure-spain-2022"
  resource_group_name = azurerm_resource_group.core.name
  location            = var.location
  os_type             = "Linux"
  sku_name            = "P1v2"

}

resource "azurerm_windows_web_app" "core" {
  name                = "app-gas2022-terraform-talk"
  resource_group_name = azurerm_resource_group.core.name
  location            = azurerm_service_plan.core.location
  service_plan_id     = azurerm_service_plan.core.id

  site_config {}
}

resource "azurerm_mssql_server" "core" {
  name                         = "sql-gas2022-terraform-talk"
  resource_group_name          = azurerm_resource_group.core.name
  location                     = azurerm_resource_group.core.location
  version                      = "12.0"
  administrator_login          = "missadministrator"
  administrator_login_password = "thisIsKat11"
  minimum_tls_version          = "1.2"
}

resource "azurerm_mssql_database" "core" {
  name           = "sqldb-gas2022-terraform-talk"
  server_id      = azurerm_mssql_server.core.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  license_type   = "LicenseIncluded"
  max_size_gb    = 2
  sku_name       = "Basic"
  zone_redundant = false
}

resource "azurerm_key_vault" "core" {
  name                        = "kv-gas2022-terra-talk"
  location                    = azurerm_resource_group.core.location
  resource_group_name         = azurerm_resource_group.core.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"

  depends_on = [
    azurerm_mssql_database.core
  ]

 lifecycle {
    ignore_changes = [
      tags
    ]
  }
}


resource "azurerm_storage_account" "example" {
  name                     = "staatodelete"
  resource_group_name      =  "rg-resources-to-import-in-terraform"
  location                 = "west europe"
  account_tier             = "Standard"
  account_replication_type = "ZRS"

}