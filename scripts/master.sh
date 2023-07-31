#! /bin/bash

NODENAME=$(hostname -s)

# pull kubeadm images
sudo kubeadm config images pull >/dev/null 2>&1
echo "Preflight Check Passed: Downloaded All Required Images"

# initialize kubeadm cluster
sudo kubeadm init --apiserver-advertise-address=$MASTER_IP  \
   --apiserver-cert-extra-sans=$MASTER_IP \
   --pod-network-cidr=$POD_CIDR --node-name $NODENAME \
   --ignore-preflight-errors Swap >> /root/kubeinit.log 2>/dev/null
echo "Kubeadm cluster initialization completed"

# Install Latest Calico Network Plugin
sudo curl -LO  https://docs.projectcalico.org/manifests/calico.yaml
sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f calico.yaml >/dev/null 2>&1
echo "Installed Latest Calico Network Plugin"

#copy kube config at home directory
sudo mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
echo "Copued kube config at master node => .kube/config"

# Save Configs to shared /Vagrant location
# For Vagrant re-runs, check if there is existing configs in the location and delete it for saving new configuration.
config_path="/vagrant/configs"

if [ -d $config_path ]; then
   rm -f $config_path/*
else
   mkdir -p /vagrant/configs
fi
echo "Created folder /vagrant/configs"  

cp -i /etc/kubernetes/admin.conf /vagrant/configs/config
touch /vagrant/configs/join.sh
chmod +x /vagrant/configs/join.sh 
echo "Created and copied join.sh at /vagrant/configs/join.sh "      

# Generete kubeadm join token
sudo kubeadm token create --print-join-command > /vagrant/configs/join.sh 2>/dev/null
echo "Genereted kubeadm join token command"  

sudo -i -u vagrant bash << EOF
mkdir -p /home/vagrant/.kube
sudo cp -i /vagrant/configs/config /home/vagrant/.kube/
sudo chown 1000:1000 /home/vagrant/.kube/config
EOF
echo "Copied from /vagrant/configs/config to /home/vagrant/.kube/ "  

# Install Metrics Server
# kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
# kubectl patch deployment metrics-server -n kube-system --type 'json' -p '[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

