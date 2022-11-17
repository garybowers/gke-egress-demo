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

locals {
  services = [
    "servicenetworking.googleapis.com",
    "dns.googleapis.com",
    "iap.googleapis.com",
    "stackdriver.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "storage-component.googleapis.com",
    "container.googleapis.com",
    "containerregistry.googleapis.com",
  ]
  subnets = [
    {
      name       = "eu-1-ext"
      region     = var.region
      cidr_range = "10.0.0.0/22"
    },
    {
      name       = "eu-1-int"
      region     = var.region
      cidr_range = "10.0.4.0/22"
    },
  ]
}

resource "random_integer" "salt" {
  min = 100000
  max = 999999
}

resource "google_folder" "folder" {
  parent       = var.folder_id
  display_name = var.prefix
}

resource "google_project" "project" {
  folder_id           = google_folder.folder.folder_id
  name                = var.prefix
  project_id          = "${var.prefix}-${random_integer.salt.result}"
  billing_account     = var.billing_account
  auto_create_network = false
}

resource "google_project_service" "project_apis" {
  project = google_project.project.project_id
  count   = length(local.services)
  service = element(local.services, count.index)

  disable_dependent_services = true
  disable_on_destroy         = true
}

resource "google_compute_network" "vpc-main" {
  name                    = "${var.prefix}-main"
  project                 = google_project.project.project_id
  auto_create_subnetworks = false
}


resource "google_compute_subnetwork" "subnet" {
  count                    = length(local.subnets)
  project                  = google_project.project.project_id
  network                  = google_compute_network.vpc-main.self_link
  name                     = "${var.prefix}-${local.subnets[count.index]["name"]}"
  region                   = local.subnets[count.index]["region"]
  ip_cidr_range            = local.subnets[count.index]["cidr_range"]
  private_ip_google_access = true
}

/* ----- Google Cloud Nat ------ */
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
    name                    = google_compute_subnetwork.subnet.1.name
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  log_config {
    filter = "TRANSLATIONS_ONLY"
    enable = true
  }
}
