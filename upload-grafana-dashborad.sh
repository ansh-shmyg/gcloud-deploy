#!/bin/bash

# wait until grafana become complated
count=0
i=0
while [ $count -lt 1 ]
do 
 (( count=$(kubectl get pods -n istio-system --kubeconfig=kubeconfig | grep 'grafana' | grep '1/1'| wc -l) ))
 sleep 4
 echo "Waiting for Grafana pod ...."
 (( i++ ))
 if [ $i -gt  225 ]
   then 
     echo "ERROR: Grafana pod have not ready in 15 minutes"
     exit 1
 fi
done

echo "Forwarding grafana pods..."
GRAF_POD=$(kubectl -n istio-system get pod -l app=grafana --kubeconfig=kubeconfig -ojsonpath='{.items[0].metadata.name}')
kubectl -n istio-system port-forward ${GRAF_POD} 3000 --kubeconfig=kubeconfig >> /dev/null 2>&1 &  
sleep 5
curl -H "Content-Type: application/json"  -d "@templates/istio/dashboard.json"  "http://127.0.0.1:3000/api/dashboards/import" ; \
pgrep kubectl | xargs kill

echo "Grafana ports are closed"

