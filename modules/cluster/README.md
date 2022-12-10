# GCP Project Module

## Description

This module creates a Google Kubernetes Engine cluster with settings to ensure it's hardened and private.

### Inputs

**project_id** -

**name** -

**prefix** -


### Outputs


### Example

module "gke-1" {
  source     = "../modules/gcp_tf_privategke"
  project_id = module.anthos_project.project_id

  name   = "cluster-a"
  prefix = var.prefix

  vpc_network = module.network.vpc_network
  subnet      = module.network.subnetwork

  location = var.region
  region   = var.region
  zone     = random_shuffle.az.result[0]

  master_ipv4_cidr_block = "192.168.0.0/28"
  whitelist_ips          = var.kube_master_whitelist

  gke_min_version = "1.15.11"

  node_pools = [{
    name         = "np-a"
    machine_type = "e2-standard-4"
    min_count    = 1
    max_count    = 10

    image_type         = "COS_CONTAINERD"
    auto_Repair        = true
    auto_upgrade       = true
    premptible         = true
    initial_node_count = 1

    disk_type    = "pd-ssd"
    disk_size_gb = 100
  }]
}

