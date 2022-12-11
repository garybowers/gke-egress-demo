output "id" {
  value = google_container_cluster.gke.id
}

output "name" {
  value = google_container_cluster.gke.name
}

output "location" {
  value = google_container_cluster.gke.location
}

output "endpoint" {
  value = google_container_cluster.gke.endpoint
}

output "gateway-np-name" {
  value = google_container_node_pool.gateway-nodepool.name
}
