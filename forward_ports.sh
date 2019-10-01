#!/bin/bash

# Script to forward local ports to Aromory Spinnaker Deck and Gate pod. 

if [ "$1" == "kill" ]; then
  echo "killing kubectl port-forward processes..." 
  pgrep kubectl | xargs kill
  exit
fi


GATE_POD=$(kubectl -n spinnaker get pod -l cluster=spin-gate --kubeconfig=kubeconfig -ojsonpath='{.items[0].metadata.name}')
kubectl -n spinnaker port-forward ${GATE_POD} 8084 --kubeconfig=kubeconfig >> /dev/null 2>&1 & 
echo "spin-gate: http://localhost:8084"

DECK_POD=$(kubectl -n spinnaker get pod -l cluster=spin-deck --kubeconfig=kubeconfig -ojsonpath='{.items[0].metadata.name}')
kubectl -n spinnaker port-forward ${DECK_POD} 9000 --kubeconfig=kubeconfig >> /dev/null 2>&1 &
echo "spin-deck: http://localhost:9000"

GRAF_POD=$(kubectl -n istio-system get pod -l app=grafana --kubeconfig=kubeconfig -ojsonpath='{.items[0].metadata.name}')
kubectl -n istio-system port-forward ${GRAF_POD} 3000 --kubeconfig=kubeconfig >> /dev/null 2>&1 &
echo "grafana: http://localhost:3000"

PROM_POD=$(kubectl -n istio-system get pod -l app=prometheus --kubeconfig=kubeconfig -ojsonpath='{.items[0].metadata.name}')
kubectl -n istio-system port-forward ${PROM_POD} 9090 --kubeconfig=kubeconfig >> /dev/null 2>&1 &
echo "prometheus: http://localhost:9090"

ZIP_POD=$(kubectl -n istio-system get pod -l app=jaeger --kubeconfig=kubeconfig -ojsonpath='{.items[0].metadata.name}')
kubectl -n istio-system port-forward ${ZIP_POD} 16686 --kubeconfig=kubeconfig >> /dev/null 2>&1 &
echo "jaeger: http://localhost:16686"

