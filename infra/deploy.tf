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

resource "google_compute_firewall" "egress-allow-ext-gw" {
  project = local.project_id
  network = google_compute_network.vpc-main.self_link

  name = "${var.prefix}-deploy-allow-ext-egress-${random_id.postfix.hex}"

  priority  = "1000"
  direction = "EGRESS"

  allow {
    protocol = "all"
  }

  destination_ranges = ["0.0.0.0/0"]

  target_service_accounts = [
    google_service_account.deploy_service_account.email,
  ]
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

git clone https://github.com/garybowers/gke-egress-demo.git /deploy

export HOME=/deploy
export USE_GKE_GCLOUD_AUTH_PLUGIN=True

cd /deploy

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
            cloud.google.com/gke-nodepool: "${var.prefix}-gateway"
EOY
cat <<EOI > ingress-gateway-spec.yaml 
apiVersion: v1
kind: Service
metadata:
  name: asm-ingressgateway
  namespace: istio-ingress
spec:
  type: ClusterIP
  selector:
    asm: ingressgateway
  ports:
  - port: 80
    name: http2
    targetPort: 8080
  - port: 443
    name: https
    targetPort: 8443
  - port: 15021
    name: status-port
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: asm-ingressgateway
  namespace: istio-ingress
spec:
  replicas: 2
  selector:
    matchLabels:
      asm: ingressgateway
  template:
    metadata:
      annotations:
        # This is required to tell Anthos Service Mesh to inject the gateway with the
        # required configuration.
        inject.istio.io/templates: gateway
      labels:
        asm: ingressgateway
        app: asm-ingressgateway # this is a legacy config but referenced by the mcs
        # istio.io/rev: asm-managed-rapid # This is required only if the namespace is not labeled.
    spec:
      containers:
      - name: istio-proxy
        image: auto # The image will automatically update each time the pod starts.
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: asm-ingressgateway-sds
  namespace: ingress-gateway 
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "watch", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: asm-ingressgateway-sds
  namespace: ingress-gateway
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: asm-ingressgateway-sds
subjects:
- kind: ServiceAccount
  name: default
EOI

curl -O https://storage.googleapis.com/csm-artifacts/asm/asmcli
chmod +x asmcli

git clone https://github.com/GoogleCloudPlatform/bank-of-anthos.git

export PROJECT=${local.project_id}

    
    bash /deploy/deploy/asm/install.sh $PROJECT

    #kubectl create ns bank-of-anthos
    #kubectl label ns bank-of-anthos istio.io/rev=$(kubectl get deploy -n istio-system -l app=istiod -o jsonpath={.items[*].metadata.labels.'istio\.io\/rev'}'{"\n"}') --overwrite

EOF

}
