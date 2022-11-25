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
  subnets = [
    {
      name       = "eu-1-ext"
      region     = var.region
      cidr_range = "10.0.0.0/22"
    },
  ]
}

resource "google_compute_network" "vpc-main" {
  name                    = "${var.prefix}-main"
  project                 = local.project_id
  auto_create_subnetworks = false
}


resource "google_compute_subnetwork" "subnet" {
  count                    = length(local.subnets)
  project                  = local.project_id
  network                  = google_compute_network.vpc-main.self_link
  name                     = "${var.prefix}-${local.subnets[count.index]["name"]}"
  region                   = local.subnets[count.index]["region"]
  ip_cidr_range            = local.subnets[count.index]["cidr_range"]
  private_ip_google_access = true
}
