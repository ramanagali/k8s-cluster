#! /bin/bash

# disable swap 
sudo swapoff -a
# keeps the swaf off during reboot
sed -i '/swap/d' /etc/fstab
echo "Disable swap and keeps the swaf off during reboot"

# disable firewall
systemctl disable --now ufw >/dev/null 2>&1
echo "Disable firewall"

# load the kernel modules
cat >>/etc/modules-load.d/containerd.conf<<EOF
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter
echo "Loaded the kernel modules"

# kernel settings Setup required sysctl params, these persist across reboots.
cat >>/etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl params without reboot
sysctl --system >/dev/null 2>&1
echo "kernel settings setup required sysctl params, these persist across reboots"

# Install containerd 
sudo apt update -qq >/dev/null 2>&1
sudo apt install -qq -y containerd apt-transport-https >/dev/null 2>&1
mkdir /etc/containerd
sudo containerd config default > /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd >/dev/null 2>&1
echo "ContainerD Runtime Configured Successfully"

#Add Kubernetes apt repository
sudo curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - >/dev/null 2>&1
sudo apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main" >/dev/null 2>&1
echo "Added Kubernetes apt repository"

#Update apt package index, install kubelet, kubeadm and kubectl, and pin their version:
sudo apt-get update -y
sudo apt install -qq -y kubelet kubectl kubeadm >/dev/null 2>&1
# sudo apt install -qq -y kubeadm=$VERSION kubelet=$VERSION kubectl=$VERSION >/dev/null 2>&1
echo "Installed kubelet kubectl kubeadm"

echo 'vagrant ALL=(ALL) NOPASSWD:ALL' | sudo tee -a /etc/sudoers
echo 'Defaults:vagrant !requiretty' | sudo tee -a /etc/sudoers

<<com
# enable ssh password authentication
sed -i 's/^PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
systemctl reload sshd
echo "Enabled ssh password authentication"

# set root password"
echo -e "kubeadmin\nkubeadmin" | passwd root >/dev/null 2>&1
echo "export TERM=xterm" >> /etc/bash.bashrc
echo "Set root password as kubeadmin"
com

# extra add sources
sudo chmod o+r /etc/resolv.conf
sudo sed -i 's/in\./us\./g' /etc/apt/sources.list
sudo systemctl restart systemd-resolved
echo "Extra add sources"

# enable dmesg for debugging
echo 'kernel.dmesg_restrict=0' | sudo tee -a /etc/sysctl.d/99-sysctl.conf
sudo service procps restart
echo "Enable dmesg for debugging"

# added kubelet args to show actual ip address 
KEA=Environment=\"KUBELET_EXTRA_ARGS=--node-ip=`ip addr show enp0s8 | grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}" | head -1`\"
sed -i "4 a $KEA" /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
sudo systemctl daemon-reload && sudo systemctl restart kubelet
echo "Added kubelet args to show actual ip address"

# set default endpoint as containerd for crictl
sudo crictl config --set runtime-endpoint=unix:///run/containerd/containerd.sock

# sudo swapoff -a && sudo systemctl daemon-reload && sudo systemctl restart kubelet