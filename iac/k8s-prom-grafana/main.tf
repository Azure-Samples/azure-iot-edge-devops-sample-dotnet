provider "azurerm" {
  # The "feature" block is required for AzureRM provider 2.x. 
  # If you are using version 1.x, the "features" block is not allowed.
  features {}
}

provider "flux" {
}

provider "kubectl" {
  host                   = try(data.azurerm_kubernetes_cluster.azkubeconfig.kube_config.0.host, null)
  username               = try(data.azurerm_kubernetes_cluster.azkubeconfig.kube_config.0.username, null)
  password               = try(data.azurerm_kubernetes_cluster.azkubeconfig.kube_config.0.password, null)
  client_key             = try(base64decode(data.azurerm_kubernetes_cluster.azkubeconfig.kube_config.0.client_key), null)
  client_certificate     = try(base64decode(data.azurerm_kubernetes_cluster.azkubeconfig.kube_config.0.client_certificate), null)
  cluster_ca_certificate = try(base64decode(data.azurerm_kubernetes_cluster.azkubeconfig.kube_config.0.cluster_ca_certificate), null)
  load_config_file       = false
  alias                  = "azure"
}

provider "kubernetes" {
  host                   = try(data.azurerm_kubernetes_cluster.azkubeconfig.kube_config.0.host, null)
  username               = try(data.azurerm_kubernetes_cluster.azkubeconfig.kube_config.0.username, null)
  password               = try(data.azurerm_kubernetes_cluster.azkubeconfig.kube_config.0.password, null)
  client_key             = try(base64decode(data.azurerm_kubernetes_cluster.azkubeconfig.kube_config.0.client_key), null)
  client_certificate     = try(base64decode(data.azurerm_kubernetes_cluster.azkubeconfig.kube_config.0.client_certificate), null)
  cluster_ca_certificate = try(base64decode(data.azurerm_kubernetes_cluster.azkubeconfig.kube_config.0.cluster_ca_certificate), null)
  alias                  = "azure"
}


terraform {
  backend "azurerm" {}
  required_providers {
    azurerm = {
      source  = "azurerm"
      version = "~>2.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
    google = {
      version = "~> 3.82.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.2"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.10.0"
    }
    flux = {
      source  = "fluxcd/flux"
      version = ">= 0.0.13"
    }
  }
}