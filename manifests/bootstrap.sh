#! /bin/bash

set -x
set -euo pipefail
#------------------------------------------------------------------------------------
# spinup vagrant cluster
vagrant box update
vagrant up

#copy the kubeconfig to local
cp configs/config ~/.kube/config

#update the vagrant cluster
vagrant ssh master -- -t 'sudo swapoff -a && sudo systemctl restart kubelet'
vagrant ssh node01 -- -t 'sudo swapoff -a && sudo systemctl restart kubelet'
#------------------------------------------------------------------------------------
#k8s journey start
kubectl cluster-info
echo "*** Kubernetes Cluster is ready to use ****"


