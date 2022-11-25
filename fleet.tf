resource "google_gke_hub_membership" "membership" {
  project       = local.project_id
  membership_id = "basic"
  endpoint {
    gke_cluster {
      resource_link = "//container.googleapis.com/${google_container_cluster.gke.id}"
    }
  }
}
