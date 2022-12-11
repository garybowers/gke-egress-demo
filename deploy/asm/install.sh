#!/usr/bin/env bash
PROJECT=$1

export USE_GKE_GCLOUD_AUTH_PLUGIN=True

for cluster in $(gcloud container clusters list --format='csv[no-heading](name,zone, endpoint)' --project="$PROJECT" )
do
    echo $cluster

    clusterName=$(echo $cluster | cut -d "," -f 1)
    clusterZone=$(echo $cluster | cut -d "," -f 2)
    clusterEndpoint=$(echo $cluster | cut -d "," -f 3)

    echo $clusterName
    echo $clusterZone
    echo $clusterEndpoint
    gcloud container clusters get-credentials $clusterName --region $clusterZone --project $PROJECT

    kubectl create ns istio-system
    kubectl create ns istio-egress
    kubectl create ns istio-ingress

    kubectl label ns istio-system istio=system
    kubectl label ns kube-system kube-system=true

    mkdir -p $clusterName/$clusterZone

    ./asmcli install --project_id ${PROJECT} \
                     --cluster_name ${CLUSTER} \
                     --cluster_location ${REGION} \
                     --output_dir ./$clusterName/$clusterZone \
                     --enable_all
                     #--custom_overlay ./asm-custom-install.yaml \

    kubectl label ns istio-egress istio=egress istio.io/rev=$(kubectl get deploy -n istio-system -l app=istiod -o \
                                  jsonpath={.items[*].metadata.labels.'istio\.io\/rev'}'{"\n"}') --overwrite

    kubectl label ns istio-ingress istio=ingress istio.io/rev=$(kubectl get deploy -n istio-system -l app=istiod -o \
                                   jsonpath={.items[*].metadata.labels.'istio\.io\/rev'}'{"\n"}') --overwrite

done
