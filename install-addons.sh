#------------------------------------------------------------------------------------
#2. helm repo add ingress
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

#prometheus helm chart default values
#helm show values ingress-nginx/ingress-nginx > ing_values.yaml

#install k8s nginx ingress controller with metrics exposed for prometheus
helm upgrade -i my-ing ingress-nginx/ingress-nginx \
    --set controller.service.type=NodePort \
    --set controller.metrics.enabled=true \
    --set controller.metrics.serviceMonitor.enabled=true \
    --set controller.metrics.serviceMonitor.additionalLabels.release="prometheus" \
    --set-string controller.podAnnotations."prometheus\.io/scrape"="true" \
    --set-string controller.podAnnotations."prometheus\.io/port"="10254"

# make sure ingress sevice monitor is enabled
kubectl apply -f manifests/ingress-sm.yaml

echo "*** Kubernetes Ingress controller Installed ****"
echo "Kubernetes Ingress controller Documentation: https://github.com/kubernetes/ingress-nginx/tree/main/charts/ingress-nginx"
#------------------------------------------------------------------------------------
#3.install prometheus
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add stable https://kubernetes-charts.storage.googleapis.com/
helm repo update

#create ns for prometheus
kubectl create ns prometheus

#prometheus helm chart default values
#helm show values prometheus-community/kube-prometheus-stack > prom_values.yaml

# prometheus operator with service monitor 
helm upgrade -i prometheus prometheus-community/kube-prometheus-stack \
    --namespace prometheus \
    --set prometheus.service.type=NodePort \
    --set ingress.enabled=true \
    --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
    --set prometheus.prometheusSpec.serviceMonitorSelector.matchLabels.release="prometheus" \
    --set alertmanager.enabled=false \
    --set kubeProxy.enabled=false \
    --set grafana.enabled=false \
    --set kubeControllerManager.enabled=false \
    --set kubeEtcd.enabled=false \
    --set kubeScheduler.enabled=false 

echo "*** Prometheus Operator Installed ****"
echo "Prometheus Operator Documentation: https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack"
#------------------------------------------------------------------------------------

kubectl run foo --image hashicorp/http-echo -- --text="<h1>Foo</h1>"
kubectl run bar --image hashicorp/http-echo -- --text="<h1>Bar</h1>"
kubectl expose po foo --name foo-svc --port 5678 
kubectl expose po bar --name bar-svc --port 5678 

kubectl apply -f ./manifests/ingress-resource.yaml
# echo 192.168.56.10 learnwithgvr.com | sudo tee -a /etc/hosts

echo "*** Foo, Bar http-echo services & Ingress Resource Installed  ****"
#------------------------------------------------------------------------------------
kubectl create deploy netshoot --image nicolaka/netshoot -- - /bin/bash
kubectl create deployment multitool --image=wbitt/network-multitool

echo "***  troubleshooting Pods ****"
#------------------------------------------------------------------------------------