terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>4.0"
    }
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = "~>1.22"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.5"
    }
  }
}
provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
}

resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  suffix      = random_id.suffix.hex
  environment = var.environment
}

resource "azurerm_resource_group" "rg" {
  name     = "${local.environment}-rg"
  location = var.location
}

# VNet and Subnets
resource "azurerm_virtual_network" "vnet" {
  name                = "${local.environment}-vnet"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
  dns_servers         = []  # Use Azure DNS
}

resource "azurerm_subnet" "db_subnet" {
  name                 = "${local.environment}-db-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]

  delegation {
    name = "dbdelegation"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_subnet" "app_subnet" {
  name                 = "${local.environment}-app-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]

  delegation {
    name = "appdelegation"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

# Private DNS Zone for PostgreSQL
resource "azurerm_private_dns_zone" "postgres" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "dns_link" {
  name                  = "${local.environment}-dns-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  registration_enabled  = true

  depends_on = [
    azurerm_virtual_network.vnet,
    azurerm_subnet.db_subnet,
    azurerm_subnet.app_subnet
  ]
}

# PostgreSQL Flexible Server
resource "azurerm_postgresql_flexible_server" "db" {
  name                   = "${local.environment}-pg-${local.suffix}"
  location               = var.location
  resource_group_name    = azurerm_resource_group.rg.name
  administrator_login    = var.db_admin
  administrator_password = var.db_password
  version                = "13"
  storage_mb             = 32768
  sku_name               = "GP_Standard_D2s_v3"
  backup_retention_days  = 7
  delegated_subnet_id    = azurerm_subnet.db_subnet.id
  private_dns_zone_id    = azurerm_private_dns_zone.postgres.id
  public_network_access_enabled = false
  zone                   = "1"

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.dns_link
  ]
}

resource "azurerm_postgresql_flexible_server_database" "appdb" {
  name      = var.db_name
  server_id = azurerm_postgresql_flexible_server.db.id
  charset   = "UTF8"
}

# Explicit A record to guarantee DNS resolution
resource "azurerm_private_dns_a_record" "postgres_record" {
  name                = azurerm_postgresql_flexible_server.db.name
  zone_name           = azurerm_private_dns_zone.postgres.name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 300
  records             = ["10.0.1.4"] # replace with actual private IP of your server
}

# Azure Container Registry
resource "azurerm_container_registry" "acr" {
  name                = "${local.environment}acr${local.suffix}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = true
}

# App Service Plan
resource "azurerm_service_plan" "plan" {
  name                = "${local.environment}-plan"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  sku_name            = "P1v2"
}

# Web App
resource "azurerm_linux_web_app" "web_app" {
  name                = "${local.environment}-webapp-${local.suffix}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_service_plan.plan.id

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on              = true
    vnet_route_all_enabled = true

    application_stack {
      docker_image_name        = var.image_name
      docker_registry_url      = "https://${azurerm_container_registry.acr.login_server}"
      docker_registry_username = azurerm_container_registry.acr.admin_username
      docker_registry_password = azurerm_container_registry.acr.admin_password
    }
  }

  app_settings = {
    DB_HOST       = "${azurerm_postgresql_flexible_server.db.name}.privatelink.postgres.database.azure.com"
    DB_NAME       = var.db_name
    DB_USER       = var.db_admin
    DB_PASS       = var.db_password
    DB_PORT       = "5432"
    WEBSITES_PORT = "8081"
  }
}

# Connect Web App to VNet
resource "azurerm_app_service_virtual_network_swift_connection" "webapp_vnet" {
  app_service_id = azurerm_linux_web_app.web_app.id
  subnet_id      = azurerm_subnet.app_subnet.id
}

# Role Assignment for ACR Pull
resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_linux_web_app.web_app.identity[0].principal_id

  depends_on = [azurerm_linux_web_app.web_app]
}
# Add this provider block
provider "postgresql" {
  host            = "${azurerm_postgresql_flexible_server.db.name}.privatelink.postgres.database.azure.com"
  port            = 5432
  database        = var.db_name
  username        = "${var.db_admin}@${azurerm_postgresql_flexible_server.db.name}"
  password        = var.db_password
  sslmode         = "require"
}

# Ensure schema exists
resource "postgresql_schema" "public" {
  name     = "public"
  database = var.db_name
}

# Create demo_table automatically
resource "postgresql_table" "demo_table" {
  name     = "demo_table"
  schema   = postgresql_schema.public.name
  database = var.db_name

  owner = "${var.db_admin}@${azurerm_postgresql_flexible_server.db.name}"

  column {
    name = "id"
    type = "serial"
  }

  column {
    name = "name"
    type = "text"
  }

  column {
    name    = "created_at"
    type    = "timestamp"
    default = "now()"
  }
}

