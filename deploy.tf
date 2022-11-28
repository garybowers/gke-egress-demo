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

resource "google_service_account" "deploy_service_account" {
  project      = local.project_id
  account_id   = "${var.prefix}-deploy-${random_id.postfix.hex}"
  display_name = "${var.prefix}-deploy-${random_id.postfix.hex}"
}

resource "google_project_iam_member" "deploy_cluster_developer" {
  project = local.project_id
  role    = "roles/container.developer"
  member  = "serviceAccount:${google_service_account.deploy_service_account.email}"
}

resource "google_project_iam_member" "deploy_asm_serviceagent" {
  project = local.project_id
  role    = "roles/anthosservicemesh.serviceAgent"
  member  = "serviceAccount:${google_service_account.deploy_service_account.email}"
}

resource "google_project_iam_member" "deploy_owner" {
  project = local.project_id
  role    = "roles/owner"
  member  = "serviceAccount:${google_service_account.deploy_service_account.email}"
}

resource "google_compute_instance" "deploy_instance" {
  project      = local.project_id
  name         = "${var.prefix}-deployment-${random_id.postfix.hex}"
  machine_type = "e2-small"
  zone         = "${var.region}-b"

  tags = ["deployer"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network    = google_compute_network.vpc-main.name
    subnetwork = google_compute_subnetwork.subnet.0.self_link
  }

  service_account {
    email  = google_service_account.deploy_service_account.email
    scopes = ["cloud-platform"]
  }

  metadata_startup_script = <<EOF
apt update -y
apt install -y kubectl ca-certificates google-cloud-sdk-gke-gcloud-auth-plugin jq git
mkdir -p /tmp/deploy
export HOME=/tmp/deploy
export USE_GKE_GCLOUD_AUTH_PLUGIN=True
gcloud container clusters get-credentials ${google_container_cluster.gke.name} --region=${google_container_cluster.gke.location}
kubectl create ns istio-system
kubectl create ns istio-egress
kubectl label ns istio-egress istio=egress istio-injection=disabled istio.io/rev=asm-1145-8 --overwrite
kubectl label ns istio-system istio=system
kubectl label ns kube-system kube-system=true
cat << 'EOY' > ./asm-custom-install.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: "egress-gateway"
spec:
  meshConfig:
    accessLogFile: "/dev/stdout"
  components:
    egressGateways:
      - name: "istio-egressgateway"
        enabled: true
        namespace: "istio-egress"
        label:
          istio: "egress"
        k8s:
          tolerations:
          - key: "dedicated"
            operator: "Equal"
            value: "gateway"
          nodeSelector:
            cloud.google.com/gke-nodepool: "${var.prefix}-np-gateway"
EOY
curl -O https://storage.googleapis.com/csm-artifacts/asm/asmcli
chmod +x asmcli
./asmcli install --project_id ${local.project_id} --cluster_name ${google_container_cluster.gke.name} \
                 --cluster_location ${google_container_cluster.gke.location} \
                  --custom_overlay ./asm-custom-install.yaml \
    --output_dir ./ \
    --enable_all
EOF

  depends_on = [google_container_node_pool.np-int]
}
