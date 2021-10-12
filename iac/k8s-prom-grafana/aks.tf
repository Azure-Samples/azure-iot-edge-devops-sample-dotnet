data "azurerm_client_config" "current" {}


resource "azurerm_kubernetes_cluster" "k8s" {
  name                = var.aks_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.aks_name

  default_node_pool {
    name       = "agentpool"
    node_count = var.k8s_agent_count
    vm_size    = "Standard_D2_v2"
  }

  identity {
    type = "SystemAssigned"
  }


  network_profile {
    load_balancer_sku = "Standard"
    network_plugin    = "kubenet"
  }
}