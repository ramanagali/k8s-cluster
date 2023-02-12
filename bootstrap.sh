#! /bin/bash

set -x
set -euo pipefail
#------------------------------------------------------------------------------------
# spinup vagrant cluster
vagrant up

#copy the kubeconfig to local
# scp root@192.168.56.10:/vagrant/configs configs/config
cp configs/config ~/.kube/config
echo "*** Local kube/config file is updated ****"
#------------------------------------------------------------------------------------
#k8s journey start
sleep 10
kubectl cluster-info 
echo "*** Kubernetes Cluster is ready to use ****"


