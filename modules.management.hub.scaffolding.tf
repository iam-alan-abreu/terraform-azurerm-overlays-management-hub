# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

#--------------------------------------
# Azure Region Lookup
#--------------------------------------
# This module will lookup the Azure Region and return the short name for the region
module "mod_azregions" {
  source  = "azurenoops/overlays-azregions-lookup/azurerm"
  version = "1.0.1"

  azure_region = var.location
}

# By default, this module will not create a resource group
# provide a name to use an existing resource group, specify the existing resource group name,
# and set the argument to `create_hub_resource_group = false`. Location will be same as existing RG.
#---------------------------------------------------------
# Resource Group Creation
#----------------------------------------------------------
data "azurerm_resource_group" "rgrp" {
  count = var.create_hub_resource_group == false ? 1 : 0
  name  = var.existing_resource_group_name
}

module "mod_scaffold_rg" {
  source  = "azurenoops/overlays-resource-group/azurerm"
  version = "1.0.1"

  count = var.create_hub_resource_group ? 1 : 0

  location                = module.mod_azregions.location_cli
  use_location_short_name = var.use_location_short_name # Use the short location name in the resource group name
  org_name                = var.org_name
  environment             = var.deploy_environment
  workload_name           = var.workload_name
  custom_rg_name          = var.custom_hub_resource_group_name != null ? var.custom_hub_resource_group_name : null

  // Tags
  add_tags = merge(local.default_tags, var.add_tags, )
}

#----------------------------------------
# Private DNS Zone RG
#----------------------------------------
module "mod_dns_rg" {
  source  = "azurenoops/overlays-resource-group/azurerm"
  version = "1.0.1"

  count = var.enable_private_dns_zones && length(var.private_dns_zones) > 0 ? 1 : 0

  location                = module.mod_azregions.location_cli
  use_location_short_name = var.use_location_short_name # Use the short location name in the resource group name
  org_name                = var.org_name
  environment             = var.deploy_environment
  workload_name           = "dns"
  custom_rg_name          = var.custom_hub_resource_group_name != null ? var.custom_hub_resource_group_name : null

  // Tags
  add_tags = merge(local.default_tags, var.add_tags, )
}

