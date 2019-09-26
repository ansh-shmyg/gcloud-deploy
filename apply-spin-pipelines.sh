#!/bin/bash
count=0
i=0
while [ $count -lt 10 ]
do 
 (( count=$(kubectl get pods -n spinnaker --kubeconfig=kubeconfig | grep '1/1' | wc -l) ))
 sleep 4
 echo "Waiting for spinnaker pods ...."
 (( i++ ))
 if [ $i -gt  225 ]
	then 
	    echo "ERROR:  Spinnaker pods have not ready in 15 minutes"
		exit
	fi
done
echo Running spin pod ...
kubectl --kubeconfig=kubeconfig apply -f spin-cli-upload-pipelines.yaml
SPIN_POD=$(kubectl -n spinnaker get pod -l app=spin-cli-install --kubeconfig=kubeconfig -ojsonpath='{.items[0].metadata.name}')
echo Finished. Check pod log: ${SPIN_POD}

