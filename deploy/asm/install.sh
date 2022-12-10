#!/usr/bin/env bash
PROJECT=$1
CLUSTER=$2
REGION=$3

export USE_GKE_GCLOUD_AUTH_PLUGIN=True
gcloud container clusters get-credentials $CLUSTER --region $REGION 

kubectl create ns istio-system
kubectl create ns istio-egress
kubectl create ns istio-ingress

kubectl label ns istio-system istio=system
kubectl label ns kube-system kube-system=true

mkdir -p $CLUSTER/$REGION

./asmcli install --project_id ${PROJECT} \
                 --cluster_name ${CLUSTER} \
                 --cluster_location ${REGION} \
                 --custom_overlay ./asm-custom-install.yaml \
                 --output_dir ./$CLUSTER/$REGION \
                 --enable_all

kubectl label ns istio-egress istio=egress istio.io/rev=$(kubectl get deploy -n istio-system -l app=istiod -o \
   jsonpath={.items[*].metadata.labels.'istio\.io\/rev'}'{"\n"}') --overwrite

kubectl label ns istio-ingress istio=ingress istio.io/rev=$(kubectl get deploy -n istio-system -l app=istiod -o \
   jsonpath={.items[*].metadata.labels.'istio\.io\/rev'}'{"\n"}') --overwrite
