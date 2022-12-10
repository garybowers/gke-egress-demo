variable "master_ipv4_cidr_block" {
  description = "The IP range in CIDR notation to use for the hosted master network. This range will be used for assigning internal IP addresses to the master or set of masters, as well as the ILB VIP. This range must not overlap with any other ranges in use within the cluster's network."
  default     = "172.16.0.0/28"
}

variable "name" {
  type        = string
  description = "The name of the cluster"
}

variable "whitelist_ips" {
  type        = list(any)
  description = "List of IP CIDR's that have access to the cluster endpoint."
}

variable "project_id" {
  type        = string
  description = "The project id to deploy to"
}

variable "prefix" {
  type        = string
  description = "The prefix of the resources"
}

variable "location" {
  type        = string
  description = "The location to deploy the cluster to"
}

variable "vpc_network" {
  type        = string
  description = "Self link to the vpc network to deploy against"
}

variable "subnet" {
  type        = string
  description = "Self link to the subnetwork to deploy to"
}

variable "gke_min_version" {
  type        = string
  description = "The mininum kubernetes version to deploy"
  default     = "1.14"
}

variable "max_nodes" {
  description = "The maximum number of nodes available to the cluster"
  default     = 4
}

variable "min_nodes" {
  description = "The minimum number of nodes available to the cluster"
  default     = 1
}

variable "node_pools" {
  type        = list(map(string))
  description = "List of maps containing node pools"
}

variable "private_endpoint" {
  description = "Enable private endpoint, default is disabled"
  default     = false
}

variable "istio_disabled" {
  default = true
}

variable "cluster_labels" {
  default = {}
}
