variable "k8s_agent_count" {
  default = 2
}

variable "location" {
  default = "westus2"
}


variable "aks_name" {
  default = "iotdashboards"
}

variable "resource_group_name" {
  default = "IoTStarter-rg"
}


variable "url" {
  description = "Flux repo url"
  default     = "https://dev.azure.com/csedevops/Observability-Monitoring/_git/observability-as-code"
}

variable "branch" {
  description = "Flux branch"
  default     = "main"
}

variable "flux_namespace" {
  default = "flux-system"
}

variable "flux_auth_secret" {
  default = "flux-auth"  
}

variable "flux_git_implementation" {
  default = "libgit2"    
}

variable "git_repo_user_name" {
}

variable "git_repo_token" {
}


variable "target_path" {
  description = "Path to sync manifests"
  default     = "./manifests/iot"
}