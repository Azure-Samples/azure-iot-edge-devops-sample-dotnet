data "azurerm_kubernetes_cluster" "azkubeconfig" {
  name                = var.aks_name
  resource_group_name = var.resource_group_name
  depends_on          = [azurerm_kubernetes_cluster.k8s]
}

data "flux_install" "main" {
  target_path = var.target_path
  namespace   = var.flux_namespace
}

data "flux_sync" "main" {
  target_path = var.target_path
  url         = var.url
  branch      = var.branch
  secret      = var.flux_auth_secret
  namespace   = var.flux_namespace
  git_implementation = var.flux_git_implementation
}

resource "kubernetes_namespace" "flux_system" {
  provider = kubernetes.azure
  depends_on = [azurerm_kubernetes_cluster.k8s]
  metadata {
    name = var.flux_namespace
  }

  lifecycle {
    ignore_changes = [
      metadata[0].labels,
    ]
  }
}


data "kubectl_file_documents" "install" {
  content = data.flux_install.main.content
}

data "kubectl_file_documents" "sync" {
  content = data.flux_sync.main.content
}

locals {
  azinstall = [for v in data.kubectl_file_documents.install.documents : {
    data : yamldecode(v)
    content : v
    }
  ]
  azsync = [for v in data.kubectl_file_documents.sync.documents : {
    data : yamldecode(v)
    content : v
    }
  ]
}

resource "kubectl_manifest" "install" {
  provider   = kubectl.azure
  depends_on = [kubernetes_namespace.flux_system]
  for_each   = { for v in local.azinstall : lower(join("/", compact([v.data.apiVersion, v.data.kind, lookup(v.data.metadata, "namespace", ""), v.data.metadata.name]))) => v.content }
  yaml_body  = each.value
}

resource "kubectl_manifest" "sync" {
  provider   = kubectl.azure
  depends_on = [kubectl_manifest.install, kubernetes_namespace.flux_system]
  for_each   = { for v in local.azsync : lower(join("/", compact([v.data.apiVersion, v.data.kind, lookup(v.data.metadata, "namespace", ""), v.data.metadata.name]))) => v.content }
  yaml_body  = each.value
}

resource "kubernetes_secret" "fluxauth" {
  provider   = kubernetes.azure
  depends_on = [kubectl_manifest.install]

  metadata {
    name      = var.flux_auth_secret
    namespace = var.flux_namespace
  }

  data = {
    username    = var.git_repo_user_name
    password    = var.git_repo_token
  }

}