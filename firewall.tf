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

data "google_netblock_ip_ranges" "netblock" {
  range_type = "google-netblocks"
}

data "google_netblock_ip_ranges" "health-checkers" {
  range_type = "health-checkers"
}

data "google_netblock_ip_ranges" "iap" {
  range_type = "iap-forwarders"
}

// Create a deny-all catch all firewall rule
resource "google_compute_firewall" "egress-disallow-all" {
  project = local.project_id
  network = google_compute_network.vpc-main.self_link

  name = "${var.prefix}-gke-node-disallow-egress-${random_id.postfix.hex}"

  priority  = "65535"
  direction = "EGRESS"

  deny {
    protocol = "all"
  }

  destination_ranges = ["0.0.0.0/0"]
}


# Create an allow to PGA egress rule for all nodes
resource "google_compute_firewall" "egress-allow-ext-pga" {
  project = local.project_id
  network = google_compute_network.vpc-main.self_link

  name = "${var.prefix}-allow-pga-egress-${random_id.postfix.hex}"

  priority  = "300"
  direction = "EGRESS"

  allow {
    protocol = "all"
  }

  destination_ranges = ["199.36.153.8/30"]
}

#Create the firewall rule to allow egress to google apis
resource "google_compute_firewall" "egress-allow-googleapis" {
  project = local.project_id
  network = google_compute_network.vpc-main.self_link

  name = "${var.prefix}-allow-engress-googleapis-${random_id.postfix.hex}"

  priority  = "100"
  direction = "EGRESS"
  allow {
    protocol = "tcp"
  }

  destination_ranges = data.google_netblock_ip_ranges.netblock.cidr_blocks_ipv4
}

// Create the firewall rules to allow health checks
resource "google_compute_firewall" "ingress-allow-gke-hc" {
  project = local.project_id
  network = google_compute_network.vpc-main.self_link

  name = "${var.prefix}-allow-ingress-hc-${random_id.postfix.hex}"

  priority  = "100"
  direction = "INGRESS"

  allow {
    protocol = "tcp"
  }

  source_ranges = data.google_netblock_ip_ranges.health-checkers.cidr_blocks_ipv4
}

// Create the firewall rules to allow IAP connection to nodes
resource "google_compute_firewall" "ingress-allow-iap" {
  project = local.project_id
  name    = "${var.prefix}-ingress-allow-iap"
  network = google_compute_network.vpc-main.name

  priority = 200

  allow {
    protocol = "tcp"
  }

  source_ranges = data.google_netblock_ip_ranges.iap.cidr_blocks_ipv4
}


// Create the firewall rules to allow pods to services communication (egress)
resource "google_compute_firewall" "egress-allow-pod-services-egress" {
  project = local.project_id
  network = google_compute_network.vpc-main.self_link

  name = "${var.prefix}-egress-allow-pod-services-egress"

  priority  = "300"
  direction = "EGRESS"

  allow {
    protocol = "all"
  }

  # replace with a variable
  destination_ranges = ["10.8.0.0/14", "10.12.0.0/20"]
}
