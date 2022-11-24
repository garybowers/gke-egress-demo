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

resource "google_compute_address" "nat_gw_address" {
  project = google_project.project.project_id
  name    = "${var.prefix}-nat-ext-addr-${var.region}-1"
  region  = var.region
}

resource "google_compute_router" "nat_router" {
  name    = "${var.prefix}-nat-rtr-1"
  project = google_project.project.project_id
  region  = var.region
  network = google_compute_network.vpc-main.self_link

  bgp {
    asn = 64514
  }
}

resource "google_compute_router_nat" "nat_gateway" {
  project = google_project.project.project_id
  name    = "${var.prefix}-nat-gw-${var.region}-1"

  router = google_compute_router.nat_router.name
  region = google_compute_router.nat_router.region

  nat_ip_allocate_option             = "MANUAL_ONLY"
  nat_ips                            = [google_compute_address.nat_gw_address.self_link]
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"


  subnetwork {
    name                    = google_compute_subnetwork.subnet.0.name
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  log_config {
    filter = "TRANSLATIONS_ONLY"
    enable = true
  }
}
