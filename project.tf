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
    "gkehub.googleapis.com",
    "mesh.googleapis.com",
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
