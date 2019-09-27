#!/bin/bash
# install istio script

helm repo add istio.io https://storage.googleapis.com/istio-release/releases/1.3.0/charts/
helm install istio.io/istio-init --name istio-init --namespace istio-system --kubeconfig=kubeconfig --wait
# wait until istio init-pods become complated
count=0
i=0
while [ $count -lt 3 ]
do 
 (( count=$(kubectl get pods -n istio-system --kubeconfig=kubeconfig | grep 'Completed' | wc -l) ))
 sleep 4
 echo "Waiting for Isio pods ...."
 (( i++ ))
 if [ $i -gt  225 ]
   then 
     echo "ERROR: Istio pods have not ready in 15 minutes"
     exit 1
 fi
done

helm install istio.io/istio --name istio --namespace istio-system -f templates/istio/istio-values.yaml --kubeconfig=kubeconfig --wait
kubectl label namespace dev istio-injection=enabled --kubeconfig=kubeconfig
kubectl label namespace prod istio-injection=enabled --kubeconfig=kubeconfig

