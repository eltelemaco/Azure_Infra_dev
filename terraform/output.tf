output "id" {
  value       = azurerm_resource_group.rg.id
  description = "ID created resource group"
}

output "location" {
  value       = azurerm_resource_group.rg.location
  description = "Location created resource group"
}

output "resource_group_name" {
  value       = azurerm_resource_group.rg.name
  description = "Resource group name"
}