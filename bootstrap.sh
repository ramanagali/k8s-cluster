#! /bin/bash

set -x
set -euo pipefail
#------------------------------------------------------------------------------------
# spinup vagrant cluster
vagrant box update
vagrant up

#copy the kubeconfig to local
# scp root@192.168.56.10:/vagrant/configs configs/config
# scp root@172.16.16.100:/etc/kubernetes/admin.conf ~/.kube/config
cp configs/config ~/.kube/config

#update the vagrant cluster
# vagrant ssh master -- -t 'sudo swapoff -a && sudo systemctl restart kubelet'
# vagrant ssh node01 -- -t 'sudo swapoff -a && sudo systemctl restart kubelet'
#------------------------------------------------------------------------------------
#k8s journey start
kubectl cluster-info 
echo "*** Kubernetes Cluster is ready to use ****"


