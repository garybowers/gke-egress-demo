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
    "iap.googleapis.com",
    "stackdriver.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "storage-component.googleapis.com",
    "container.googleapis.com",
    "monitoring.googleapis.com",
    "containerregistry.googleapis.com",
    "gkehub.googleapis.com",
    "mesh.googleapis.com",
    "meshconfig.googleapis.com",
    "meshca.googleapis.com",
    "anthos.googleapis.com",
    "containerregistry.googleapis.com",
    "connectgateway.googleapis.com",
    "opsconfigmonitoring.googleapis.com",
    "serviceusage.googleapis.com",
    "multiclusteringress.googleapis.com",
    "multiclusterservicediscovery.googleapis.com",
  ]
  project_id     = google_project.project.project_id
  project_number = google_project.project.number
}

resource "random_integer" "salt" {
  min = 100000
  max = 999999
}

resource "google_folder" "folder" {
  parent       = var.folder_id
  display_name = "${var.prefix}-demo"
}

resource "google_project" "project" {
  folder_id           = google_folder.folder.folder_id
  name                = var.prefix
  project_id          = "${var.prefix}-${random_integer.salt.result}"
  billing_account     = var.billing_account
  auto_create_network = false
}

resource "google_project_service" "dns_api" {
  project = local.project_id
  service = "dns.googleapis.com"

  disable_on_destroy = false
}

resource "google_project_service" "project_apis" {
  project = local.project_id
  count   = length(local.services)
  service = element(local.services, count.index)

  disable_on_destroy = false

  provisioner "local-exec" {
    command = "sleep 10"
  }
}

resource "google_compute_project_metadata" "default" {
  project = local.project_id
  metadata = {
    enable-oslogin = "TRUE"
  }
  lifecycle {
    ignore_changes = [metadata]
  }
}

