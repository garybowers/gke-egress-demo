/**
 * Copyright 2022 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

resource "random_id" "postfix" {
  byte_length = 4
}

resource "google_service_account" "gke_service_account" {
  project      = google_project.project.project_id
  account_id   = "${var.prefix}-gke-${random_id.postfix.hex}"
  display_name = "${var.prefix}-gke-${random_id.postfix.hex}"
}

resource "google_service_account" "gke_egress_service_account" {
  project      = google_project.project.project_id
  account_id   = "${var.prefix}-gke-egress-${random_id.postfix.hex}"
  display_name = "${var.prefix}-gke-egress-${random_id.postfix.hex}"
}

resource "google_service_account" "gke_worker_service_account" {
  project      = google_project.project.project_id
  account_id   = "${var.prefix}-gke-worker-${random_id.postfix.hex}"
  display_name = "${var.prefix}-gke-worker-${random_id.postfix.hex}"
}

resource "google_container_registry" "registry" {
  project = google_project.project.project_id
}

resource "google_storage_bucket_iam_member" "viewer" {
  bucket = google_container_registry.registry.id
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.gke_service_account.email}"
}

resource "google_project_iam_member" "service_account_log_writer" {
  project = google_project.project.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_service_account.email}"
}

resource "google_project_iam_member" "service_account_metric_writer" {
  project = google_project.project.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_service_account.email}"
}

resource "google_project_iam_member" "service_account_monitoring_viewer" {
  project = google_project.project.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.gke_service_account.email}"
}


// Create the firewall rules to allow health checks

resource "google_compute_firewall" "ingress-allow-gke-hc" {
  project = google_project.project.project_id
  network = google_compute_network.vpc-main.self_link

  name = "${var.prefix}-gke-node-allow-ingress-hc-${random_id.postfix.hex}"

  priority  = "100"
  direction = "INGRESS"

  allow {
    protocol = "tcp"
  }

  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
}

// Create the firewall rules to allow nodes to communicate with the control plane
resource "google_compute_firewall" "egress-allow-gke-node" {
  project = google_project.project.project_id
  network = google_compute_network.vpc-main.self_link

  name = "${var.prefix}-gke-node-allow-egress-${random_id.postfix.hex}"

  priority  = "200"
  direction = "EGRESS"

  allow {
    protocol = "tcp"
    ports    = ["443", "9443", "10250", "15017", "6443"]
  }

  destination_ranges = [var.master_ipv4_cidr_block]
  target_service_accounts = [google_service_account.gke_worker_service_account.email,
  google_service_account.gke_egress_service_account.email]
}

resource "google_compute_firewall" "ingress-allow-gke-node" {
  project = google_project.project.project_id
  network = google_compute_network.vpc-main.self_link

  name = "${var.prefix}-gke-node-allow-ingress-${random_id.postfix.hex}"

  priority  = "200"
  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["443", "9443", "10250", "15017", "6443"]
  }

  source_ranges = [var.master_ipv4_cidr_block]
  source_service_accounts = [
    google_service_account.gke_worker_service_account.email,
    google_service_account.gke_egress_service_account.email
  ]
}

// Create the GKE Cluster
resource "google_container_cluster" "gke" {
  provider = google-beta

  project  = google_project.project.project_id
  name     = "${var.prefix}-${random_id.postfix.hex}"
  location = var.region

  network    = google_compute_network.vpc-main.self_link
  subnetwork = google_compute_subnetwork.subnet.0.self_link

  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"

  min_master_version = "1.24.5"

  remove_default_node_pool = true
  initial_node_count       = 1
  enable_shielded_nodes    = true
  enable_legacy_abac       = false

  resource_labels = {
    mesh_id = "proj-${google_project.project.number}",
  }

  master_auth {
    // Disable login auth to the cluster
    //username = ""
    //password = ""

    client_certificate_config {
      issue_client_certificate = false
    }
  }

  maintenance_policy {
    daily_maintenance_window {
      start_time = "03:00"
    }
  }

  node_config {
    labels = {
      private-pool = "true"
    }

    shielded_instance_config {
      enable_secure_boot          = "true"
      enable_integrity_monitoring = "true"
    }

    preemptible = false

    service_account = google_service_account.gke_service_account.email
  }

  workload_identity_config {
    workload_pool = "${google_project.project.project_id}.svc.id.goog"
  }

  private_cluster_config {
    enable_private_endpoint = true
    enable_private_nodes    = true
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }

  master_authorized_networks_config {
  }

  ip_allocation_policy {
  }

  network_policy {
    enabled  = true
    provider = "CALICO"
  }

  addons_config {
    network_policy_config {
      disabled = false
    }
  }

  //resource_labels = var.cluster_labels

  lifecycle {
    ignore_changes = [master_auth]
  }

  timeouts {
    create = "30m"
    update = "40m"
    delete = "2h"
  }

  depends_on = [google_compute_firewall.egress-allow-gke-node, google_compute_firewall.ingress-allow-gke-node]
}

resource "google_container_node_pool" "np-ext" {
  project     = google_project.project.project_id
  name_prefix = "${var.prefix}-np-ext"
  location    = var.region
  cluster     = google_container_cluster.gke.name

  node_config {
    image_type   = "COS_CONTAINERD"
    machine_type = "n1-standard-2"

    disk_size_gb = 100
    disk_type    = "pd-balanced"

    preemptible = false

    metadata = {
      disable-legacy-endpoints = "true"
    }

    labels = {
      private-pool = "true",
      type         = "egress"
    }

    shielded_instance_config {
      enable_secure_boot          = "true"
      enable_integrity_monitoring = "true"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    service_account = google_service_account.gke_egress_service_account.email
  }

  initial_node_count = 1

  autoscaling {
    min_node_count  = 1
    max_node_count  = 5
    location_policy = "BALANCED"
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  timeouts {
    create = "30m"
    update = "40m"
    delete = "2h"
  }

  lifecycle {
    create_before_destroy = true
  }

}

// Workload nodepool
resource "google_container_node_pool" "np-int" {
  project     = google_project.project.project_id
  name_prefix = "${var.prefix}-np-wl1"
  location    = var.region
  cluster     = google_container_cluster.gke.name

  node_config {
    image_type   = "COS_CONTAINERD"
    machine_type = "n1-standard-2"

    disk_size_gb = 100
    disk_type    = "pd-balanced"

    preemptible = false

    metadata = {
      disable-legacy-endpoints = "true"
    }

    labels = {
      private-pool = "true"
    }

    shielded_instance_config {
      enable_secure_boot          = "true"
      enable_integrity_monitoring = "true"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    service_account = google_service_account.gke_worker_service_account.email
  }

  initial_node_count = 1

  autoscaling {
    min_node_count  = 1
    max_node_count  = 5
    location_policy = "BALANCED"
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  timeouts {
    create = "30m"
    update = "40m"
    delete = "2h"
  }

  lifecycle {
    create_before_destroy = true
  }

}
