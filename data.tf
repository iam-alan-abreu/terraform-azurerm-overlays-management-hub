# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

# remove file if not needed
data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "netwatch" {
  depends_on = [azurerm_virtual_network.hub_vnet]  
  name       = "NetworkWatcherRG"
}

data "azurerm_network_watcher" "nwatcher" {
  depends_on = [ azurerm_virtual_network.hub_vnet ]
  name                = "NetworkWatcher_${local.location}"  
  resource_group_name = data.azurerm_resource_group.netwatch.name
}