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

resource "google_dns_managed_zone" "private-google-apis" {
  project     = local.project_id
  name        = "private-google-apis"
  dns_name    = "googleapis.com."
  description = "Private DNS zone for Google APIs"
  visibility  = "private"

  private_visibility_config {
    networks {
      network_url = google_compute_network.vpc-main.id
    }
  }
}

resource "google_dns_record_set" "private-google-apis-c" {
  project = local.project_id
  name    = "*.${google_dns_managed_zone.private-google-apis.dns_name}"
  type    = "CNAME"
  ttl     = 300

  managed_zone = google_dns_managed_zone.private-google-apis.name

  rrdatas = [
    "private.googleapis.com."
  ]
}

resource "google_dns_record_set" "private-google-apis-a" {
  project = local.project_id
  name    = "private.${google_dns_managed_zone.private-google-apis.dns_name}"
  type    = "A"
  ttl     = 300

  managed_zone = google_dns_managed_zone.private-google-apis.name

  rrdatas = [
    "199.36.153.8",
    "199.36.153.9",
    "199.36.153.10",
    "199.36.153.11"
  ]
}
