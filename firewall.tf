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

// Create a deny-all catch all firewall rule.

resource "google_compute_firewall" "egress-disallow-all" {
  project = google_project.project.project_id
  network = google_compute_network.vpc-main.self_link

  name = "${var.prefix}-gke-node-disallow-egress-${random_id.postfix.hex}"

  priority  = "65535"
  direction = "EGRESS"

  deny {
    protocol = "all"
  }

  destination_ranges      = ["0.0.0.0/0"]
  target_service_accounts = [google_service_account.service_account.email]
}

resource "google_compute_firewall" "egress-allow-ext-gw" {
  project = google_project.project.project_id
  network = google_compute_network.vpc-main.self_link

  name = "${var.prefix}-gke-node-allow-ext-egress-${random_id.postfix.hex}"

  priority  = "1000"
  direction = "EGRESS"

  allow {
    protocol = "all"
  }

  destination_ranges = ["0.0.0.0/0"]

  target_tags = ["egress-allow"]
}
