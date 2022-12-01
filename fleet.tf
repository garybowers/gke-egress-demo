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

resource "google_gke_hub_membership" "membership" {
  project       = local.project_id
  membership_id = "basic"
  endpoint {
    gke_cluster {
      resource_link = "//container.googleapis.com/${google_container_cluster.gke.id}"
    }
  }
  authority {
    issuer = "https://container.googleapis.com/v1/${google_container_cluster.gke.id}"
  }
}

resource "google_gke_hub_membership" "membership-2" {
  project       = local.project_id
  membership_id = "basic-2"
  endpoint {
    gke_cluster {
      resource_link = "//container.googleapis.com/${google_container_cluster.gke-2.id}"
    }
  }
  authority {
    issuer = "https://container.googleapis.com/v1/${google_container_cluster.gke-2.id}"
  }
}

resource "google_gke_hub_feature" "mesh" {
  name     = "servicemesh"
  project  = local.project_id
  location = "global"
  provider = google-beta
}

resource "google_gke_hub_feature" "mci" {
  name     = "multiclusteringress"
  project  = local.project_id
  location = "global"
  provider = google-beta

  spec {
    multiclusteringress {
      config_membership = google_gke_hub_membership.membership.id
    }
  }
}
