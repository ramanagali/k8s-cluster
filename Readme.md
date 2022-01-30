# Kubernetes Cluster with Ingress, Prometheus Monitoring and Measure Benchmarking
1. Spin up a multi-node Kubernetes cluster using vagrant 
2. Install and run the NGINX ingress controller.
3. Install and run Prometheus, and configure it to monitor the Ingress Controller pods and Ingress resources created by the controller.
4. Deploy an Ingress resource and two instances of a backend service using the “hashicorp/http-echo”. The Ingress should send requests with path “/foo” to one service; and path “/bar” to another. The services should respond with “foo” and “bar” respectively.
5. Run a benchmarking tool `wrk` against the Ingress.
6. Generate a CSV file of time-series data using PromQL to fetch the following metrics from Prometheus:
   * Average requests per second
   * Average memory usage per second
   * Average CPU usage per second

## Create Multi Node K8S cluster using Vagrant & VirtualBox
### 1. Prerequisites (Mandatory)
* Install Brew using https://brew.sh/
* Install virutalbox using `brew install --cask virtualbox`         
  * follow steps https://www.virtualbox.org/wiki/Downloads
* Install vagrant using `brew install vagrant`
  * https://www.vagrantup.com/docs/installation
* Install Helm `brew install helm`      
  * https://helm.sh/docs/intro/install/
* Install Go using https://go.dev/doc/install
* Install wrk http benchmarking tools using `brew install wrk`
  * https://github.com/wg/wrk

### 2. Mandatory Step for MacOS Montereyclea
Bun below...
```sh
sudo mkdir -p /etc/vbox/
echo * 0.0.0.0/0 ::/0 | sudo tee -a /etc/vbox/networks.conf
```

### 3. Checkout the Repo
Clone the repo locally by running below command 
  
```sh 
git clone the repo https://github.com/ramanagali/k8s-cluster-podman.git
cd k8s-cluster-prometheus
```

### 4. Bootstrapping k8s cluster using kubeadm
Run below command to provision new kubeadm cluster

```sh
./bootstrap.sh
```

### 5. Install k8s Ingress Controller, Prometheus & Ingress resource 
* Run below command to Install latest Ingress Controller, Prometheus using helm.  
* It will deploy foo, bar (http-echo) services (as NodePort) along with Ingress Resource

```sh
./install-addons.sh
```

**NOTE**: Wait 2-5mins to see ingress controller target healty

### 6. Access Ingress Controller Resource from browser
* Run below commands to get the Ingress URL 
* Open the URL in browser (Cmd/Ctrl + Click)

```sh
export NODE_IP=192.168.56.10
export ING_PORT=$(kubectl get svc my-ing-ingress-nginx-controller -o jsonpath="{.spec.ports[0].nodePort}")
echo "http://$NODE_IP:$ING_PORT/foo"
echo "http://$NODE_IP:$ING_PORT/bar"
```
### 7. Access Prometheus Server from browser
Run below commands to get the Prometheus Server URL & open the URL in browser (Cmd/Ctrl + Click)
```sh
export NODE_IP=192.168.56.10
export PROM_PORT=$(kubectl get svc -n prometheus prometheus-kube-prometheus-prometheus -o jsonpath="{.spec.ports[0].nodePort}")
echo "http://$NODE_IP:$PROM_PORT"
```

### 8. Run HTTP Benchmarking tests against foo, boor ingress resources
Total HTTP Load test - duration is 30 seconds for each service
* 1st strike - 100 connections, 30 seconds for each service (foo & bar)
* 2nd strike - 200 connections, 30 seconds for each service
* 3rd strike - 400 connections, 30 seconds for each service
  
```sh
./loadtest.sh
```

#### 8.1 Queries Timeseries data to CSV
Run Below commands in Prom server

```
PROM_URL=http://$NODE_IP:$PROM_PORT:9090   
echo $PROM_URL
```

1. Average requests per second 
`avg(rate(nginx_ingress_controller_nginx_process_requests_total[4h]))`

2. Average memory usage per second
`avg(rate(process_resident_memory_bytes{service="my-ing-ingress-nginx-controller-metrics"}[4h]))`

3. Average CPU usage per second
`avg(rate(process_cpu_seconds_total{service="my-ing-ingress-nginx-controller-metrics"}[4h]))`


#### 8.2 Export Timeseries data to CSV
```
PROM_URL=http://$NODE_IP:$PROM_PORT:9090   
echo $PROM_URL
```
1. Average requests per second 
`curl -fs --data-urlencode 'query=avg(rate(nginx_ingress_controller_nginx_process_requests_total[4h]))' $PROM_URL/api/v1/query | jq -r '.data.result[] | .value[1]' > avg_req_ps.csv`

2. Average memory usage per second
`curl -fs --data-urlencode 'query=avg(rate(process_resident_memory_bytes{service="my-ing-ingress-nginx-controller-metrics"}[4h]))' $PROM_URL/api/v1/query | jq -r '.data.result[].value[1]'  > avg_mem_ps.csv`

3. Average CPU usage per second
`curl -fs --data-urlencode 'query=avg(rate(process_cpu_seconds_total{service="my-ing-ingress-nginx-controller-metrics"}[4h]))' $PROM_URL/api/v1/query | jq -r '.data.result[].value[1]' > > avg_cpu_ps.csv`


#### 9. Stop k8s cluster

```sh
vagrant halt
```
NOTE: for strating the cluster refer [2. Bootstrapping](#2-bootstrapping-k8s-cluster-using-kubeadm)

#### 10. Cleanup k8s cluster
```sh
vagrant destroy -f
```