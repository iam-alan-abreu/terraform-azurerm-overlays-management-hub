# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

/*
SUMMARY: Module to deploy a route table and associated routes
DESCRIPTION: The following components will be options in this deployment
              * Route Table
                * Route Table Association
                * Route
AUTHOR/S: jrspinella
*/

/* module "hub_route_table" {
  source  = "azure/avm-res-network-routetable/azurerm"
  version = "0.3.0"

  //Globals
  name                          = local.hub_rt_name
  resource_group_name           = local.resource_group_name
  location                      = local.location
  bgp_route_propagation_enabled = var.disable_bgp_route_propagation

  # Routes
  routes = {
    for_each = var.route_table_routes
    "default-route-${each.value.route_name}" = {
      name                   = lower(format("route-to-firewall-%s", each.value.route_name))
      address_prefix         = each.value.address_prefix
      next_hop_type          = each.value.next_hop_type
      next_hop_in_ip_address = each.value.next_hop_in_ip_address
    },
    force_internet_tunneling = var.enable_firewall && var.enable_forced_tunneling ? {
      name                   = lower(format("route-to-firewall-%s", local.hub_vnet_name))
      address_prefix         = var.ip_cidr_tunneling == null ? "0.0.0.0/0" : var.ip_cidr_tunneling
      next_hop_type          = "VirtualAppliance"
      next_hop_in_ip_address = module.hub_fw[0].resource.ip_configuration[0].private_ip_address
    } : null,
  }

  # Subnet Assoc
  subnet_resource_ids = {
    for_each             = var.hub_subnets
    "subnet-${each.key}" = azurerm_subnet.default_snet[each.key].id
  }

  # Resource Lock
  lock = var.enable_resource_locks ? {
    name = "${local.ddos_plan_name}-${var.lock_level}-lock"
    kind = var.lock_level
  } : null

  # telemtry
  enable_telemetry = var.enable_telemetry

  # tags
  tags = merge({ "ResourceName" = format("%s", local.ddos_plan_name) }, local.default_tags, var.add_tags, )
}

# Encrypted Transport Route Table
resource "azurerm_route_table" "afw_routetable" {
  name                          = local.hub_afw_rt_name
  resource_group_name           = local.resource_group_name
  location                      = local.location
  bgp_route_propagation_enabled = false
  tags                          = merge({ "ResourceName" = "afw-subnet-route-network-outbound" }, local.default_tags, var.add_tags, )

  count = var.enable_encrypted_transport ? 1 : 0
}

resource "azurerm_subnet_route_table_association" "afw_rtassoc" {
  subnet_id      = azurerm_subnet.firewall_client_snet[0].id
  route_table_id = azurerm_route_table.afw_routetable[0].id

  count = var.enable_encrypted_transport ? 1 : 0
}

resource "azurerm_route" "afw_route" {
  name                   = lower(format("route-to-afw-subnet-%s", local.location))
  resource_group_name    = local.resource_group_name
  route_table_name       = azurerm_route_table.afw_routetable[0].name
  address_prefix         = var.encrypted_transport_address_prefix
  next_hop_type          = var.encrypted_transport_next_hop_type
  next_hop_in_ip_address = var.encrypted_transport_next_hop_in_ip_address

  count = var.enable_encrypted_transport ? 1 : 0
} */


resource "azurerm_route_table" "routetable" {
  name                          = local.hub_rt_name
  resource_group_name           = local.resource_group_name
  location                      = local.location
  bgp_route_propagation_enabled = var.disable_bgp_route_propagation
  tags                          = merge({ "ResourceName" = "route-network-outbound" }, local.default_tags, var.add_tags, )
}

# resource "azurerm_subnet_route_table_association" "rtassoc" {
#  for_each       = var.hub_subnets
#  subnet_id      = module.default_snet[each.key].resource_id
#  route_table_id = azurerm_route_table.routetable.id
# }

# resource "azurerm_subnet_route_table_association" "rtassoc" {
#  for_each = { for k, v in var.hub_subnets : k => v if k != var.excluded_subnet }
#  subnet_id      = module.default_snet[each.key].resource_id
#  route_table_id = azurerm_route_table.routetable.id
# }

resource "azurerm_subnet_route_table_association" "rtassoc" {
  for_each = {
    for k in sort(keys({ for k, v in var.hub_subnets : k => v if k != var.excluded_subnet })) : k => var.hub_subnets[k]}
    subnet_id      = module.default_snet[each.key].resource_id
    route_table_id = azurerm_route_table.routetable.id

    lifecycle {
    create_before_destroy = true
  }

  depends_on = [azurerm_route_table.routetable]
}


resource "azurerm_route" "force_internet_tunneling" {
  name                   = lower(format("route-to-firewall-%s", local.hub_vnet_name))
  resource_group_name    = local.resource_group_name
  route_table_name       = azurerm_route_table.routetable.name
  address_prefix         = var.ip_cidr_tunneling == null ? "0.0.0.0/0" : var.ip_cidr_tunneling
  next_hop_in_ip_address = module.hub_fw[0].resource.ip_configuration[0].private_ip_address
  next_hop_type          = "VirtualAppliance"

  count = var.enable_firewall && var.enable_forced_tunneling ? 1 : 0
}

resource "azurerm_route" "route" {
  for_each               = var.route_table_routes
  name                   = lower(format("route-to-firewall-%s", each.value.route_name))
  resource_group_name    = local.resource_group_name
  route_table_name       = azurerm_route_table.routetable.name
  address_prefix         = each.value.address_prefix
  next_hop_type          = each.value.next_hop_type
  next_hop_in_ip_address = each.value.next_hop_in_ip_address
}

# Encrypted Transport Route Table
resource "azurerm_route_table" "afw_routetable" {
  name                          = local.hub_afw_rt_name
  resource_group_name           = local.resource_group_name
  location                      = local.location
  bgp_route_propagation_enabled = false
  tags                          = merge({ "ResourceName" = "afw-subnet-route-network-outbound" }, local.default_tags, var.add_tags, )

  count = var.enable_encrypted_transport ? 1 : 0
}

resource "azurerm_subnet_route_table_association" "afw_rtassoc" {
  subnet_id      = module.firewall_client_snet[0].resource_id
  route_table_id = azurerm_route_table.afw_routetable[0].id

  count = var.enable_encrypted_transport ? 1 : 0
}

resource "azurerm_route" "afw_route" {
  name                   = lower(format("route-to-afw-subnet-%s", local.location))
  resource_group_name    = local.resource_group_name
  route_table_name       = azurerm_route_table.afw_routetable[0].name
  address_prefix         = var.encrypted_transport_address_prefix
  next_hop_type          = var.encrypted_transport_next_hop_type
  next_hop_in_ip_address = var.encrypted_transport_next_hop_in_ip_address

  count = var.enable_encrypted_transport ? 1 : 0
}
