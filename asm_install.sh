#!/usr/bin/env bash
# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


kubectl create ns istio-system
kubectl create ns istio-egress

kubectl label ns istio-egress istio=egress istio-injection=disabled
kubectl label ns istio-system istio=system
kubectl label ns kube-system kube-system=true

cat << 'EOF' > ./asm-custom-install.yaml
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
            cloud.google.com/gke-nodepool: "gateway"
EOF


curl -O https://storage.googleapis.com/csm-artifacts/asm/asmcli
chmod +x asmcli

./asmcli install \
    --project_id ${PROJECT_ID} \
    --cluster_name cluster1 \
    --cluster_location ${ZONE} \
    --custom_overlay ./asm-custom-install.yaml \
    --output_dir ./ \
    --enable_all
