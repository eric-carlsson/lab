#!/bin/bash

set -ex

cluster_name="opensearch"
dir_name="$(dirname "$0")"

if ! kind get clusters | grep -q "${cluster_name}"; then
    kind create cluster -n "${cluster_name}"
else
    kubectl config use-context "kind-${cluster_name}"
fi

if ! helm status flux --namespace flux-system; then
    helm upgrade flux https://github.com/fluxcd-community/helm-charts/releases/download/flux2-2.16.0/flux2-2.16.0.tgz \
        --install \
        --wait \
        --namespace flux-system \
        --create-namespace
fi

kubectl apply -f "${dir_name}/opensearch.yaml" --namespace flux-system

kubectl wait \
    --for=condition=Ready=True \
    --timeout=300s \
    --namespace flux-system \
    $(kubectl get helmreleases.helm.toolkit.fluxcd.io --namespace flux-system -o name)

kubectl apply -f "${dir_name}/ingest.yaml" --namespace flux-system
