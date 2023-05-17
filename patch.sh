#!/bin/sh
set -euo pipefail

CUSTOM_KUBECONFIG=/tmp/kubeconfig
to_update=0
meshNetworks="networks:"

# foreach remote cluster
for remote_secret in $(kubectl get secrets -n istio-system -o=name --field-selector type=Opaque | grep remote-secret); do
    echo "Getting cluster name for remote cluster from $remote_secret"
    remote_cluster_name=$(kubectl get "$remote_secret" -n istio-system -o jsonpath='{.metadata.annotations.networking\.istio\.io/cluster}')
    echo "Got cluster name: $remote_cluster_name"
    echo "Getting kubeconfig for remote cluster from $remote_secret"
    kubectl get "$remote_secret" -n istio-system -o jsonpath='{.data.*}' | base64 -d > $CUSTOM_KUBECONFIG
    echo "Got kubeconfig"
    echo "Getting eastwestgateway's hostname"
    hostname=$(KUBECONFIG=$CUSTOM_KUBECONFIG kubectl get service -n istio-system istio-eastwestgateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    echo "Got eastwestgateway's hostname: $hostname"
    echo "Getting network name"
    remote_cluster_network=$(KUBECONFIG=$CUSTOM_KUBECONFIG kubectl get service -n istio-system istio-eastwestgateway -o jsonpath='{.metadata.labels.topology\.istio\.io/network}')
    echo "Got network name: $remote_cluster_network"
    echo "Resolving $hostname"
    IPs=$(dig +short "$hostname")
    echo "Got IPs: $IPs"
    meshNetworks="$meshNetworks\n  $remote_cluster_network:\n    endpoints:\n      - fromRegistry: $remote_cluster_name\n    gateways:"
    for IP in $IPs; do
        echo "Checking $IP in istio configmap"
        if [[ "$(kubectl get configmaps -n istio-system istio -o jsonpath='{.data.meshNetworks}' | grep "$IP")" == '' ]]; then
            echo "$IP not found in configmap, going to update it"
            to_update=1
        fi
        meshNetworks="$meshNetworks\n      - address: $IP\n        port: 15443"
    done
done

if [[ $to_update == 1 ]]; then
    echo "Configmap before patching"
    kubectl get configmap -n istio-system istio -o yaml
    echo "Patching configmap with:\n$meshNetworks"
    kubectl patch configmap istio -n istio-system --type merge -p "{\"data\":{\"meshNetworks\":\"$meshNetworks\"}}"
    echo "Configmap after patching"
    kubectl get configmap -n istio-system istio -o yaml
fi
