module "rg" {
  source = "git::https://ORGANIZATION_NAME@dev.azure.com/ORGANIZATION_NAME/PROJECT_NAME/_git/terraform.azurerm.rg?ref=v1.2.0"

  name     = "example-rg"
  location = "westeurope"

  tags = {
    environment = "production"
    deployedBy  = "Terraform"
    foo         = "bar"
  }
}