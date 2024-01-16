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
cat >>/etc/modules-load.d/kubernetes.conf<<EOF
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

#verify the modules are loaded
lsmod | grep br_netfilter
lsmod | grep overlay
echo "kernel settings setup required sysctl params, these persist across reboots"

if [ "$RUNTIME" = "containerd" ]; 
then
  # Install containerd 
  sudo apt update -qq >/dev/null 2>&1
  sudo apt-get install -y ca-certificates curl gnupg
  sudo mkdir -p /etc/apt/keyrings
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt update 
  sudo apt install --allow-unauthenticated -qq -y containerd.io apt-transport-https >/dev/null 2>&1
  sudo mkdir -p /etc/containerd
  sudo containerd config default > /etc/containerd/config.toml
  sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
  
  sudo systemctl restart containerd
  sudo systemctl enable containerd >/dev/null 2>&1
  sudo systemctl status containerd.service

  echo "$RUNTIME Runtime $RUNTIME_VERSION Configured Successfully"
elif [ "$RUNTIME" = "crio" ]; 
then
  # Install CRI-O
  OS=xUbuntu_22.04
  echo $RUNTIME_VERSION
  echo "deb [signed-by=/usr/share/keyrings/libcontainers-archive-keyring.gpg] https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/ /" > /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
  echo "deb [signed-by=/usr/share/keyrings/libcontainers-crio-archive-keyring.gpg] https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$RUNTIME_VERSION/$OS/ /" > /etc/apt/sources.list.d/devel:kubic:libcontainers:stable:cri-o:$RUNTIME_VERSION.list
  mkdir -p /usr/share/keyrings
  curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/Release.key | gpg --dearmor -o /usr/share/keyrings/libcontainers-archive-keyring.gpg
  curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$RUNTIME_VERSION/$OS/Release.key | gpg --dearmor -o /usr/share/keyrings/libcontainers-crio-archive-keyring.gpg
  apt-get update
  apt-get install cri-o cri-o-runc cri-tools -y

  sudo systemctl start crio.service
  sudo systemctl enable crio.service
  sudo systemctl status crio.service

  sudo crictl --version
  echo "$RUNTIME Runtime $RUNTIME_VERSION Configured Successfully"
fi

#Add Kubernetes apt repository
# sudo curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg >/dev/null 2>&1
# echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null 2>&1

sudo apt-get install -y apt-transport-https ca-certificates curl gpg
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg  >/dev/null 2>&1

# This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list  >/dev/null 2>&1
echo "Added Kubernetes apt repository"

#Update apt package index, install kubelet, kubeadm and kubectl, and pin their version:
sudo apt-get update --allow-unauthenticated --allow-insecure-repositories -y
sudo apt install --allow-unauthenticated -qq -y kubelet kubectl kubeadm >/dev/null 2>&1
#sudo apt install -qq -y kubeadm=$VERSION kubelet=1.25.5-00 kubectl=$VERSION >/dev/null 2>&1
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

if [ "$RUNTIME" = "containerd" ]; 
then
  # set download latest crictl
  CTLVERSION=$(curl -s https://api.github.com/repos/kubernetes-sigs/cri-tools/releases/latest | grep "tag_name" | cut -d '"' -f 4)

  sudo wget -q https://github.com/kubernetes-sigs/cri-tools/releases/download/$CTLVERSION/crictl-$CTLVERSION-linux-amd64.tar.gz
  sudo tar zxvf crictl-$CTLVERSION-linux-amd64.tar.gz -C /usr/local/bin
  rm -f crictl-$CTLVERSION-linux-amd64.tar.gz

  sudo crictl config --set runtime-endpoint=unix:///run/containerd/containerd.sock
  sudo crictl --version
fi

# VERSION=$(curl -s https://api.github.com/repos/containerd/containerd/releases/latest | grep 'tag_name' | cut -d '"' -f 4)
# sudo curl -L "https://github.com/containerd/containerd/releases/download/${VERSION}/containerd-${VERSION#v}-linux-amd64.tar.gz" -o containerd.tar.gz
# sudo tar -xzf containerd.tar.gz
# sudo mv bin/* /usr/local/bin/

# sudo mkdir -p /etc/containerd
# sudo curl -L "https://raw.githubusercontent.com/containerd/containerd/main/containerd-config.toml" -o /etc/containerd/config.toml

# sudo systemctl start containerd
# sudo systemctl enable containerd
# sudo systemctl status containerd
# sudo containerd --version

# sudo swapoff -a && sudo systemctl daemon-reload && sudo systemctl restart kubelet