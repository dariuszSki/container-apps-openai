terraform {
  required_version = ">= 1.3"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.65"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "kubernetes" {
  host                   = module.aks.host
  client_key             = base64decode(module.aks.client_key)
  client_certificate     = base64decode(module.aks.client_certificate)
  cluster_ca_certificate = base64decode(module.aks.cluster_ca_certificate)
}

provider "helm" {
  debug   = true
  kubernetes {
    host                   = module.aks.host
    client_key             = base64decode(module.aks.client_key)
    client_certificate     = base64decode(module.aks.client_certificate)
    cluster_ca_certificate = base64decode(module.aks.cluster_ca_certificate)
  }
}

data "azurerm_client_config" "current" {
}

resource "random_string" "prefix" {
  length  = 6
  special = false
  upper   = false
  numeric = false
}

resource "azurerm_resource_group" "rg" {
  name     = var.name_prefix == null ? "${random_string.prefix.result}${var.resource_group_name}" : "${var.name_prefix}${var.resource_group_name}"
  location = var.location
  tags     = var.tags
}

module "log_analytics_workspace" {
  source                           = "./modules/log_analytics"
  name                             = var.name_prefix == null ? "${random_string.prefix.result}${var.log_analytics_workspace_name}" : "${var.name_prefix}${var.log_analytics_workspace_name}"
  location                         = var.location
  resource_group_name              = azurerm_resource_group.rg.name
  tags                             = var.tags
}

module "virtual_network" {
  source                           = "./modules/virtual_network"
  resource_group_name              = azurerm_resource_group.rg.name
  vnet_name                        = var.name_prefix == null ? "${random_string.prefix.result}${var.vnet_name}" : "${var.name_prefix}${var.vnet_name}"
  location                         = var.location
  address_space                    = var.vnet_address_space
  tags                             = var.tags
  log_analytics_workspace_id       = module.log_analytics_workspace.id
  log_analytics_retention_days     = var.log_analytics_retention_days

  subnets = [
    {
      name : var.aca_subnet_name
      address_prefixes : var.aca_subnet_address_prefix
      private_endpoint_network_policies_enabled : true
      private_link_service_network_policies_enabled : false
    },
    {
      name : var.private_endpoint_subnet_name
      address_prefixes : var.private_endpoint_subnet_address_prefix
      private_endpoint_network_policies_enabled : true
      private_link_service_network_policies_enabled : false
    }
  ]
}

module "acr_private_dns_zone" {
  source                       = "./modules/private_dns_zone"
  name                         = "privatelink.azurecr.io"
  resource_group_name          = azurerm_resource_group.rg.name
  tags                         = var.tags
  virtual_networks_to_link     = {
    (module.virtual_network.name) = {
      subscription_id = data.azurerm_client_config.current.subscription_id
      resource_group_name = azurerm_resource_group.rg.name
    }
  }
}

module "openai_private_dns_zone" {
  source                       = "./modules/private_dns_zone"
  name                         = "privatelink.openai.azure.com"
  resource_group_name          = azurerm_resource_group.rg.name
  tags                         = var.tags
  virtual_networks_to_link     = {
    (module.virtual_network.name) = {
      subscription_id = data.azurerm_client_config.current.subscription_id
      resource_group_name = azurerm_resource_group.rg.name
    }
  }
}

module "openai_private_endpoint" {
  source                         = "./modules/private_endpoint"
  name                           = "${module.openai.name}PrivateEndpoint"
  location                       = var.location
  resource_group_name            = azurerm_resource_group.rg.name
  subnet_id                      = module.virtual_network.subnet_ids[var.private_endpoint_subnet_name]
  tags                           = var.tags
  private_connection_resource_id = module.openai.id
  is_manual_connection           = false
  subresource_name               = "account"
  private_dns_zone_group_name    = "OpenAiPrivateDnsZoneGroup"
  private_dns_zone_group_ids     = [module.openai_private_dns_zone.id]
}

module "acr_private_endpoint" {
  source                         = "./modules/private_endpoint"
  name                           = "${module.container_registry.name}PrivateEndpoint"
  location                       = var.location
  resource_group_name            = azurerm_resource_group.rg.name
  subnet_id                      = module.virtual_network.subnet_ids[var.private_endpoint_subnet_name]
  tags                           = var.tags
  private_connection_resource_id = module.container_registry.id
  is_manual_connection           = false
  subresource_name               = "registry"
  private_dns_zone_group_name    = "AcrPrivateDnsZoneGroup"
  private_dns_zone_group_ids     = [module.acr_private_dns_zone.id]
}

module "openai" {
  source                        = "./modules/openai"
  name                          = var.name_prefix == null ? "${random_string.prefix.result}${var.openai_name}" : "${var.name_prefix}${var.openai_name}"
  location                      = var.location
  resource_group_name           = azurerm_resource_group.rg.name
  sku_name                      = var.openai_sku_name
  tags                          = var.tags
  deployments                   = var.openai_deployments
  custom_subdomain_name         = var.openai_custom_subdomain_name == "" || var.openai_custom_subdomain_name == null ? var.name_prefix == null ? lower("${random_string.prefix.result}${var.openai_name}") : lower("${var.name_prefix}${var.openai_name}") : lower(var.openai_custom_subdomain_name)
  public_network_access_enabled = var.openai_public_network_access_enabled
  log_analytics_workspace_id    = module.log_analytics_workspace.id
  log_analytics_retention_days  = var.log_analytics_retention_days
}

module "container_registry" {
  source                       = "./modules/container_registry"
  name                         = var.name_prefix == null ? "${random_string.prefix.result}${var.acr_name}" : "${var.name_prefix}${var.acr_name}"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = var.location
  sku                          = var.acr_sku
  admin_enabled                = var.acr_admin_enabled
  georeplication_locations     = var.acr_georeplication_locations
  log_analytics_workspace_id   = module.log_analytics_workspace.id
  log_analytics_retention_days = var.log_analytics_retention_days
  tags                         = var.tags

}

module "workload_managed_identity" {
  source                       = "./modules/managed_identity"
  name                         = var.name_prefix == null ? "${random_string.prefix.result}${var.workload_managed_identity_name}" : "${var.name_prefix}${var.workload_managed_identity_name}"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = var.location
  openai_id                    = module.openai.id
  acr_id                       = module.container_registry.id
  tags                         = var.tags
}

module "container_app_environment" {
  source                           = "./modules/container_app_environment"
  name                             = var.name_prefix == null ? "${random_string.prefix.result}${var.container_app_environment_name}" : "${var.name_prefix}${var.container_app_environment_name}"
  location                         = var.location
  resource_group_name              = azurerm_resource_group.rg.name
  tags                             = var.tags
  infrastructure_subnet_id         = module.virtual_network.subnet_ids[var.aca_subnet_name] 
  internal_load_balancer_enabled   = var.internal_load_balancer_enabled
  log_analytics_workspace_id       = module.log_analytics_workspace.id
}

module "aks_identity" {
  source                       = "./modules/managed_identity"
  name                         = "${var.name_prefix}aksid"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = var.location
  openai_id                    = module.openai.id
  acr_id                       = module.container_registry.id
  tags                         = var.tags
}


module "aks" {
  source                                       = "Azure/aks/azurerm"
  version                                      = "7.3.2"
  cluster_name                                 = lower("${var.name_prefix}akscluster")
  prefix                                       = lower("${var.name_prefix}akscluster")
  resource_group_name                          = azurerm_resource_group.rg.name
  location                                     = var.location
  identity_ids                                 = [module.aks_identity.id]
  identity_type                                = "UserAssigned"
  oidc_issuer_enabled                          = true
  workload_identity_enabled                    = true
  vnet_subnet_id                               = module.virtual_network.subnet_ids[var.aca_subnet_name]
  net_profile_service_cidr                     = "10.0.20.0/22"
  net_profile_dns_service_ip                   = "10.0.20.2"
  rbac_aad                                     = false
  network_contributor_role_assigned_subnet_ids = {
    vnet_subnet = module.virtual_network.subnet_ids[var.aca_subnet_name]
  }
  private_cluster_enabled                      = true
  network_plugin                               = "azure"
  network_policy                               = "azure"
  os_disk_size_gb                              = 60
  sku_tier                                     = "Standard"
  depends_on                                   = [ azurerm_resource_group.rg ]
}

resource "azurerm_federated_identity_credential" "federated_identity_credential" {
  name                = "${module.aks_identity.name}FederatedIdentity"
  resource_group_name = azurerm_resource_group.rg.name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = module.aks.oidc_issuer_url
  parent_id           = module.aks_identity.id
  subject             = "system:serviceaccount:chatbot:chatbot-sa"
}

resource "azurerm_public_ip" "public_ip" {
  name                = lower("${var.name_prefix}publicip")
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"         
}

resource "azurerm_network_security_group" "edge_router_nsg" {
  name                = "${var.name_prefix}-nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_network_security_rule" "edge_router_sg_ssh" {
  name                        = "ssh"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.edge_router_nsg.name
}

module "edge-router" {
  source                        = "Azure/compute/azurerm"
  version                       = "5.3.0"
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = var.location
  vnet_subnet_id                = module.virtual_network.subnet_ids[var.aca_subnet_name]
  network_security_group        = {
    id = azurerm_network_security_group.edge_router_nsg.id
  }
  allocation_method              = "Static"
  public_ip_sku                  = "Standard"
  admin_username                 = "ziggy"
  ssh_key                        = var.ziti_router_ssh_pub
  custom_data                    = "#cloud-config\nruncmd:\n- [/opt/netfoundry/router-registration, ${var.ziti_router_reg_key}]"
  delete_os_disk_on_termination  = true
  enable_ip_forwarding           = true
  is_marketplace_image           = true
  vm_hostname                    = lower("${var.name_prefix}zitirouter")
  vm_os_offer                    = "ziti-edge-router"
  vm_os_publisher                = "netfoundryinc"
  vm_os_sku                      = "ziti-edge-router"
  vm_os_version                  = "latest"
  vm_size                        = "Standard_DS1_v2"
}

resource "local_sensitive_file" "kubeconfig" {
  depends_on   = [module.aks]
  filename     = pathexpand("~/.kube/config")
  content      = module.aks.kube_config_raw
  file_permission = 0600
}

resource "azurerm_role_assignment" "kubeconfig" {
  principal_id                     = module.aks.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = module.container_registry.id
  skip_service_principal_aad_check = true
}

# ziti edge enroll --jwt /mnt/c/users/dsliwinski/k8s-zet-host.jwt --out /tmp/k8s-zet-host.json
# helm install k8s-zet-host openziti/ziti-host --set-file zitiIdentity=/tmp/k8s-zet-host.json --create-namespace --namespace ziti
