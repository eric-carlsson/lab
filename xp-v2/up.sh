#!/bin/bash

set -ex

cluster_name="xp-v2"
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

kubectl apply -f "${dir_name}/charts/crossplane.yaml" --namespace flux-system

kubectl wait \
    --for=condition=Ready=True \
    --timeout=90s \
    --namespace flux-system \
    $(kubectl get helmreleases.helm.toolkit.fluxcd.io --namespace flux-system -o name)

kubectl apply -k "${dir_name}/crossplane/packages"

kubectl wait \
    --for=condition=Healthy=True \
    --timeout=90s \
    $(kubectl get functions.pkg.crossplane.io -o name) \
    $(kubectl get providers.pkg.crossplane.io -o name)

kubectl apply -k "${dir_name}/crossplane/apis"
kubectl apply -k "${dir_name}/crossplane/configs"
kubectl apply -k "${dir_name}/crossplane/resources"
