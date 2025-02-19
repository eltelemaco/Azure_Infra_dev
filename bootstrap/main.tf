data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "state" {
  name = var.resource_group_name
}

resource "azurerm_management_lock" "terraform-resource-group" {
  name       = "terraform"
  scope      = data.azurerm_resource_group.state.id
  lock_level = "CanNotDelete"
  notes      = "Protects the terraform state files and key vault."
}

locals {
  location = coalesce(var.location, data.azurerm_resource_group.state.location)
  tags     = merge(data.azurerm_resource_group.state.tags, var.tags)
}
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.1.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "=2.6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "=3.0.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "=2.1.0"
    }
  }
}
provider "azuread" {
  tenant_id = data.azurerm_client_config.current.tenant_id
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}
