#!/bin/bash

CORE_CLUSTER=${cluster_name}
CORE_USER=core-spinnaker-service-account
KUBECONFIG_FILE=spinnaker-kubeconfig
SPINNAKER_SA=create-spinnaker-sa.yaml

# Create spinnaker kubeconfig file
kubectl --kubeconfig=kubeconfig apply -f $SPINNAKER_SA
CORE_TOKEN=$(kubectl  --kubeconfig=kubeconfig  get secret \
    $(kubectl --kubeconfig=kubeconfig get serviceaccount spinnaker-service-account \
    -n spinnaker \
    -o jsonpath='{.secrets[0].name}') \
    -n spinnaker \
    -o jsonpath='{.data.token}' | base64 --decode)

kubectl --kubeconfig=kubeconfig config view --raw -o json | jq -r '.clusters[] | select(.name == "'${cluster_name}'") | .cluster."certificate-authority-data"' | base64 -d > core_cluster_ca.crt
CORE_SERVER=$(kubectl --kubeconfig=kubeconfig config view --raw -o json | jq -r '.clusters[] | select(.name == "'${cluster_name}'") | .cluster."server"')
kubectl config --kubeconfig=$KUBECONFIG_FILE set-cluster $CORE_CLUSTER \
    --certificate-authority=./core_cluster_ca.crt \
    --embed-certs=true \
    --server $CORE_SERVER

kubectl config --kubeconfig=$KUBECONFIG_FILE set-credentials $CORE_USER --token $CORE_TOKEN
kubectl config --kubeconfig=$KUBECONFIG_FILE set-context core --user $CORE_USER --cluster $CORE_CLUSTER
kubectl --kubeconfig=kubeconfig create secret generic --from-file=./spinnaker-kubeconfig --from-file=./gcp-service-account.json spin-secrets -n spinnaker

# Install konfig Maps for tests
kubectl --kubeconfig=kubeconfig apply -f spin-config/tests-config-maps.yaml
# install spinaker
kubectl --kubeconfig=kubeconfig apply -f haliard-install.yaml
