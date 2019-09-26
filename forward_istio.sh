###Port forward
#!/bin/bash
GRAF_POD=$(kubectl -n istio-system get pod -l app=grafana --kubeconfig=kubeconfig -ojsonpath='{.items[0].metadata.name}')
kubectl -n istio-system port-forward ${GRAF_POD} 3000 --kubeconfig=kubeconfig >> /dev/null 2>&1 &
PROM_POD=$(kubectl -n istio-system get pod -l app=prometheus --kubeconfig=kubeconfig -ojsonpath='{.items[0].metadata.name}')
kubectl -n istio-system port-forward ${PROM_POD} 9090 --kubeconfig=kubeconfig >> /dev/null 2>&1 &
ZIP_POD=$(kubectl -n istio-system get pod -l app=jaeger -ojsonpath='{.items[0].metadata.name}')
kubectl -n istio-system port-forward ${ZIP_POD} 9411 --kubeconfig=kubeconfig >> /dev/null 2>&1 &

