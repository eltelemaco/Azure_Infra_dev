#!/bin/bash
MSYS_NO_PATHCONV=1

read -e -i eastus -p "Azure region        : " location
read -e -i rg-nuevo-bootstrap  -p "resource group name : " resource_group_name
read -e -i tfstate    -p "container name      : " container_name

location=${location:-westeurope}
resource_group_name=${resource_group_name:-terraform}
container_name=${container:-tfstate}
subscription_id=$(az account show --query id --output tsv)
scope="/subscriptions/$subscription_id"
echo "$scope" 


upn=$(az ad signed-in-user show --query userPrincipalName --output tsv)
if [ $? -ne 0 ]
then
  echo "Failed to get userPrincipalName"
  exit 1
fi
echo "upn: $upn"

group_created=$(az group create --name $resource_group_name --subscription $subscription_id --location $location --output json)
if [ $? -ne 0 ]
then
  echo "Failed to create resource group $resource_group_name in $location"
  exit 1
fi
echo "Created resource group $resource_group_name in $location"
# Check to see if the user is already a member of the Owner role
role_created=$(az role assignment create --assignee $upn --role Owner --scope $scope)
if [ $? -ne 0 ]
then
  echo "Failed to assign Owner role $role_created to $upn and scope $socpe"  
  exit 1
fi
echo "Assigned Owner role to $upn"
# Check to see if the user is already a member of the Storage Blob Data Owner role

# Check to see if existing storage account exists
jmespath_query="[? tags.created_by == 'bootstrap_backend.sh']|[0].name"
storage_account_name=$(az storage account list --resource-group $resource_group_name --query "$jmespath_query" --output tsv)

if [ -n "$storage_account_name" ]
then
  echo "Found existing storage account $storage_account_name in $resource_group_name. Reusing."
else
  storage_account_name=terraform$(tr -dc "[:lower:][:digit:]" < /dev/urandom | head -c 15)
  az storage account create --name $storage_account_name --resource-group $resource_group_name --kind StorageV2 --sku Standard_RAGRS --tags created_by=bootstrap_backend.sh
fi
storage_account_id="$(az storage account show --name $storage_account_name --resource-group $resource_group_name --query id --output tsv)"
echo "Storage account ID: $storage_account_id"

az role assignment create --assignee $upn --scope $storage_account_id --role "Storage Blob Data Owner" --subscription $subscription_id --scope $scope

storage_account_key=$(az storage account keys list --resource-group $resource_group_name --account-name $storage_account_name --output tsv --query "[1].value")
az storage container create --name $container_name --account-name $storage_account_name --account-key $storage_account_key

# Try to get the latest version of the azurerm_provider
azurerm_latest_version=$(curl --silent "https://api.github.com/repos/terraform-providers/terraform-provider-azurerm/releases/latest" 2>/dev/null | jq -r .name 2>/dev/null | sed 's/^v//1' | cut -f1-2 -d.)
[[ "$azurerm_latest_version" == "null" ]] && unset azurerm_latest_version

if [[ "$azurerm_latest_version" == "" ]]
then version_constraint="~> 2.0"
else version_constraint="~> $azurerm_latest_version"
fi

cat > bootstrap_backend.tf <<BOOTSTRAP_BACKEND
terraform {
  backend "azurerm" {
    resource_group_name  = "$resource_group_name"
    storage_account_name = "$storage_account_name"
    container_name       = "$container_name"
    key                  = "bootstrap.tfstate"

  }
}

BOOTSTRAP_BACKEND

echo "bootstrap_backend.tf:"
cat bootstrap_backend.tf

cat > bootstrap_backend.auto.tfvars <<BOOTSTRAP_BACKEND_TFVARS
resource_group_name        = "$resource_group_name"
storage_account_name       = "$storage_account_name"
container_name             = "$container_name"
azurerm_version_constraint = "$version_constraint"

BOOTSTRAP_BACKEND_TFVARS

echo "bootstrap_backend.auto.tfvars:"
cat bootstrap_backend.auto.tfvars

exit 0
