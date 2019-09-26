#!/bin/bash

# Script to forward local ports to Aromory Spinnaker Deck and Gate pod. 

if [ "$1" == "kill" ]; then
  echo "killing kube port-forward"
  pgrep kubectl | xargs kill
  exit
fi


GATE_POD=$(kubectl -n spinnaker get pod -l cluster=spin-gate --kubeconfig=kubeconfig -ojsonpath='{.items[0].metadata.name}')
kubectl -n spinnaker port-forward ${GATE_POD} 8084 --kubeconfig=kubeconfig >> /dev/null 2>&1 & 

DECK_POD=$(kubectl -n spinnaker get pod -l cluster=spin-deck --kubeconfig=kubeconfig -ojsonpath='{.items[0].metadata.name}')
kubectl -n spinnaker port-forward ${DECK_POD} 9000 --kubeconfig=kubeconfig >> /dev/null 2>&1 &

