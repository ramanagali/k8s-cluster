#! /bin/bash

config_path="/vagrant/configs"

/bin/bash $config_path/join.sh -v
echo "Executed join.sh to join the $(hostname -s) to cluster"  

sudo -i -u vagrant bash << EOF
whoami
mkdir -p /home/vagrant/.kube
sudo cp -i $config_path/config /home/vagrant/.kube/
sudo chown 1000:1000 /home/vagrant/.kube/config
NODENAME=$(hostname -s)
kubectl label node $(hostname -s) node-role.kubernetes.io/worker=worker-new
EOF
echo "Copied .kube/config and labled worker node"  .