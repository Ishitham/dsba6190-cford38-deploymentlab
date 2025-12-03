////////////////////////////////////////////////////
// Tags
////////////////////////////////////////////////////
locals {
  tags = {
    class      = var.tag_class
    instructor = var.tag_instructor
    semester   = var.tag_semester
  }
}

////////////////////////////////////////////////////
// Random Suffix
////////////////////////////////////////////////////
resource "random_integer" "deployment_id_suffix" {
  min = 100
  max = 999
}

////////////////////////////////////////////////////
// Resource Group
////////////////////////////////////////////////////
resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.class_name}-${var.student_name}-${var.environment}-${var.location}-${random_integer.deployment_id_suffix.result}"
  location = var.location
  tags     = local.tags
}

////////////////////////////////////////////////////
// Storage Account
////////////////////////////////////////////////////
resource "azurerm_storage_account" "storage" {
  # storage account name MUST be lowercase and <=24 chars
  name                     = "stodsba${random_integer.deployment_id_suffix.result}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = local.tags
}

////////////////////////////////////////////////////
// Virtual Network
////////////////////////////////////////////////////
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet${random_integer.deployment_id_suffix.result}"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  tags = local.tags
}

////////////////////////////////////////////////////
// Subnet
////////////////////////////////////////////////////
resource "azurerm_subnet" "subnet" {
  name                 = "subnet${random_integer.deployment_id_suffix.result}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]

  # Required for storage + SQL vNet rules
  service_endpoints = [
    "Microsoft.Storage",
    "Microsoft.Sql",
  ]
}

////////////////////////////////////////////////////
// Storage Account Network Rules (VNET-ONLY ACCESS)
////////////////////////////////////////////////////
resource "azurerm_storage_account_network_rules" "storage_rules" {
  storage_account_id = azurerm_storage_account.storage.id

  default_action             = "Deny"                     # block public traffic
  virtual_network_subnet_ids = [azurerm_subnet.subnet.id] # allow only vNet subnet
  bypass                     = ["AzureServices"]          # allow Azure internal services
}

////////////////////////////////////////////////////
// SQL Server
////////////////////////////////////////////////////
resource "azurerm_mssql_server" "sql" {
  name                = "sql${random_integer.deployment_id_suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  version             = "12.0"

  administrator_login          = "sqladminuser"
  administrator_login_password = "ChangeThisP@ssword123!" # change before submitting

  tags = local.tags
}

////////////////////////////////////////////////////
// SQL Database
////////////////////////////////////////////////////
resource "azurerm_mssql_database" "sqldb" {
  name        = "sqldb${random_integer.deployment_id_suffix.result}"
  server_id   = azurerm_mssql_server.sql.id
  sku_name    = "Basic"
  max_size_gb = 2
}

////////////////////////////////////////////////////
// SQL Virtual Network Rule
////////////////////////////////////////////////////
resource "azurerm_mssql_virtual_network_rule" "sql_vnet_rule" {
  name      = "sql-vnet-rule-${random_integer.deployment_id_suffix.result}"
  server_id = azurerm_mssql_server.sql.id
  subnet_id = azurerm_subnet.subnet.id
}
