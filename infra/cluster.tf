data "google_compute_subnetwork" "my-subnetwork" {
  project = local.project_id
  count   = length(var.clusters)
  name    = google_compute_subnetwork.subnet[count.index].name
  region  = var.clusters[count.index]["location"]
}

module "cluster" {
  count      = length(var.clusters)
  source     = "./modules/cluster"
  project_id = local.project_id

  name   = var.clusters[count.index]["name"]
  prefix = var.prefix

  whitelist_ips = var.clusters[count.index]["cp-auth-networks"]
  location      = var.clusters[count.index]["location"]

  private_endpoint       = true
  master_ipv4_cidr_block = var.clusters[count.index]["master_cidr_block"]

  vpc_network = google_compute_network.vpc-main.self_link
  subnet      = data.google_compute_subnetwork.my-subnetwork[count.index].self_link

  node_pools = [
    {
      name         = "np-a"
      machine_type = "e2-standard-4"
      min_count    = 1
      max_count    = 10

      image_type         = "COS_CONTAINERD"
      auto_repair        = true
      auto_upgrade       = true
      preemptible        = false
      initial_node_count = 1
    }
  ]
}
