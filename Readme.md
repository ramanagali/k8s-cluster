## Kubernetes Cluster with Ingress, Prometheus Monitoring and Measure Benchmarking
1. Spin up a multi-node Kubernetes cluster using vagrant 
2. Install and run the NGINX ingress controller.
3. Install and run Prometheus, and configure it to monitor the Ingress Controller pods and Ingress resources created by the controller.
4. Deploy an Ingress resource and two instances of a backend service using the “hashicorp/http-echo”. The Ingress should send requests with path “/foo” to one service; and path “/bar” to another. The services should respond with “foo” and “bar” respectively.
5. Run a benchmarking tool `wrk` against the Ingress.
6. Generate a CSV file of time-series data using PromQL to fetch the following metrics from Prometheus:
   * Average requests per second
   * Average memory usage per second
   * Average CPU usage per second

### Create Multi Node K8S cluster using Vagrant & VirtualBox
#### 1. Mandatory Prerequisites
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
* Clone the repo using `git clone the repo https://github.com/ramanagali/k8s-cluster-podman.git`
* cd k8s-cluster-prometheus
* git update-index --chmod=+x path/to/file

### 2. Mandatory Step for MacOS Monterey
run below...
```sh
sudo mkdir -p /etc/vbox/
echo * 0.0.0.0/0 ::/0 | sudo tee -a /etc/vbox/networks.conf
```
#### 2. Bootstrapping k8s cluster using kubeadm
run below command to provision kubeadm cluster

```sh
./bootstrap.sh
```

#### 3. Install k8s Ingress Controller, Prometheus 
```sh
./install-addons.sh
```

NOTE: Wait 2-5mins to see ingress controller target healty

#### 4. Access Ingress Controller Resource from browser
run below commands to get the Ingress URL & open the URL in browser (Cmd/Ctrl + Click)

```sh
export NODE_IP=192.168.56.10
export ING_PORT=$(kubectl get svc my-ing-ingress-nginx-controller -o jsonpath="{.spec.ports[0].nodePort}")
echo "http://$NODE_IP:$ING_PORT/foo"
echo "http://$NODE_IP:$ING_PORT/bar"
```
#### 5. Run HTTP Benchmarking tests against foo, boor ingress resources
Total HTTP Load test Duration is 1 min for each service
* 1st strike - 200 connections, 30 seconds
* 2nd strike - 400 connections, 40 seconds
  
```sh
./loadtest.sh
```

#### 6. Access Prometheus Server from browser
Run below commands to get the Prometheus Server URL & open the URL in browser (Cmd/Ctrl + Click)
```sh
export NODE_IP=192.168.56.10
export PROM_PORT=$(kubectl get svc -n prometheus prometheus-kube-prometheus-prometheus -o jsonpath="{.spec.ports[0].nodePort}")
echo "http://$NODE_IP:$PROM_PORT"
```

##### 6.1 Queries Timeseries data to CSV

1. Average requests per second 
```sh
rate(http_requests_total[1s]) (rate averaged per second)
rate(http_requests_total[5m]) * 60 (minute rate averaged over 5 minutes)
avg_over_time(sum(rate(http_request_counter[1s])) by (method, some_other_label)[1d])
```
2. Average memory usage per second
`rate(process_resident_memory_bytes[1s])`

3. Average CPU usage per second
`rate(process_cpu_seconds_total[1s])`

4. Average Throughput per second
`rate(sample_app_histogram_request_duration_seconds_count[1s])`

5. Number of Requests per minute
`sum(increase(sample_app_histogram_request_duration_seconds_count[1m])) by (job)`

<!-- echo "http://$NODE_IP:$PROM_PORT/api/v1/query?query=cpu[1h]" -->

https://prometheus.io/docs/prometheus/latest/querying/examples/\
https://prometheus.io/docs/prometheus/latest/querying/basics/#time-series-selectors
https://www.robustperception.io/prometheus-query-results-as-csv
https://prometheus.io/docs/prometheus/latest/querying/api/#instant-queries

##### 6.2 Export Timeseries data to CSV

#### 7. Stop k8s cluster

```sh
vagrant halt
```
NOTE: for strating the cluster refer [2. Bootstrapping](#2-bootstrapping-k8s-cluster-using-kubeadm)

#### 4. Cleanup k8s cluster
```sh
vagrant destroy -f
```