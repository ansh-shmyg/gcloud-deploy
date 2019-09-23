# In what namespace to deploy our own stack
STACK_NAMESPACE=default
ISTIO_IMAGE_TAG=release-1.1-20190213-09-16
ISTIO_NAMESPACE=istio-system
ISTIO_CHART_REPO=https://gcsweb.istio.io/gcs/istio-prerelease/prerelease/1.1.0-snapshot.6/charts/



# Istio init
kubectl create ns $ISTIO_NAMESPACE
helm repo add istio.io $ISTIO_CHART_REPO
helm upgrade --install istio-init istio.io/istio-init --namespace $ISTIO_NAMESPACE

sleep 25s

# Istio install
helm upgrade --install istio istio.io/istio \
  --namespace $ISTIO_NAMESPACE \
  --set global.tag=$ISTIO_IMAGE_TAG \
  --set galley.enabled=true \
  --set security.enabled=true \
  --set mixer.policy.enabled=true \
  --set mixer.telemetry.enabled=true \
  --set pilot.enabled=true \
  --set prometheus.enabled=true \
  --set tracing.enabled=false \
  --set kiali.enabled=false \
  --set servicegraph.enabled=false \
  --set grafana.enabled=true \
  --set ingress.autoscaleMin=2 \
  --set ingress.replicaCount=2 \
  --set gateways.istio-ingressgateway.autoscaleMin=2 \
  --set gateways.istio-ingressgateway.replicaCount=2 \
  --set mixer.istio-policy.autoscaleEnabled=true \
  --set global.controlPlaneSecurityEnabled=false \
  --set global.mtls.enabled=false \
  --set global.outboundTrafficPolicy.mode=ALLOW_ANY \
  --set global.defaultResources.requests.memory=50Mi \
  --set global.defaultResources.requests.cpu=50m \
  --set global.proxy.resources.requests.memory=50Mi \
  --set global.proxy.resources.requests.cpu=50m \
  --set sidecarInjectorWebhook.enabled=true \
  # (...)
  # see: https://github.com/istio/istio/tree/master/install/kubernetes/helm/istio#configuration

kubectl label namespace $STACK_NAMESPACE istio-injection=enabled --overwrite

