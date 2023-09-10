output "log_analytics_name" {
   value = module.log_analytics_workspace.name
}

output "log_analytics_workspace_id" {
   value = module.log_analytics_workspace.workspace_id
}

output "ziti_router_public_ip_address" {
   value = azurerm_public_ip.public_ip.ip_address
}

output "aks_cluster_name" {
  value = module.aks.aks_name
}

output "aks_private_fqdn" {
  value = module.aks.cluster_private_fqdn
}

output "aks_oidc_issuer_url" {
  value = module.aks.oidc_issuer_url
}
