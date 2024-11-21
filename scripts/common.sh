#! /bin/bash

# DNS Setting
if [ ! -d /etc/systemd/resolved.conf.d ]; then
	sudo mkdir /etc/systemd/resolved.conf.d/
fi
cat <<EOF | sudo tee /etc/systemd/resolved.conf.d/dns_servers.conf
[Resolve]
DNS=${DNS_SERVERS}
EOF

sudo systemctl restart systemd-resolved

# disable swap 
sudo swapoff -a
# keeps the swaf off during reboot
sed -i '/swap/d' /etc/fstab
(crontab -l 2>/dev/null; echo "@reboot /sbin/swapoff -a") | crontab - || true
sudo apt-get update -y
echo "[1] Disable swap and keeps the swaf off during reboot"

# disable firewall
systemctl disable --now ufw
echo "[2] Disable firewall"

# load the kernel modules
cat >>/etc/modules-load.d/kubernetes.conf<<EOF
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter
echo "[3] Loaded the kernel modules"

# kernel settings Setup required sysctl params, these persist across reboots.
cat >>/etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system

#verify the modules are loaded
lsmod | grep br_netfilter
lsmod | grep overlay
echo "[4] Kernel settings setup required sysctl params, these persist across reboots"

if [ "$RUNTIME" = "containerd" ]; 
then
  # Install containerd
  export DEBIAN_FRONTEND=noninteractive 
  sudo apt-get update -qq
  sudo apt-get install -qq -y apt-transport-https ca-certificates curl gnupg lsb-release socat
  sudo mkdir -p /etc/apt/keyrings
  # sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg
  echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list

  sudo apt-get update -qq
  sudo apt-get install -qq -y containerd.io
  sudo containerd config default > /etc/containerd/config.toml
  sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml

  sudo systemctl restart containerd
  sudo systemctl enable containerd

  echo "[5] $RUNTIME Runtime $RUNTIME_VERSION Configured Successfully"
elif [ "$RUNTIME" = "crio" ]; 
then
  # Install CRI-O
  # OS=xUbuntu_22.04
  # echo $RUNTIME_VERSION

  apt-get install -y software-properties-common curl apt-transport-https ca-certificates

  curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/Release.key |
      gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg
  echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/ /" |
      tee /etc/apt/sources.list.d/cri-o.list

  sudo apt-get update -y
  sudo apt-get install -y cri-o

  sudo systemctl daemon-reload
  sudo systemctl enable crio --now
  sudo systemctl start crio.service

  # sudo crictl --version
  echo "$RUNTIME Runtime $RUNTIME_VERSION Configured Successfully"
fi

#Add Kubernetes apt repository configuration in /etc/apt/sources.list.d/kubernetes.list
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v$K8S_VERSION/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v$K8S_VERSION/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
echo "[6] Added Kubernetes apt repository"

#Update apt package index, install kubelet, kubeadm and kubectl, and pin their version:
sudo apt-get update -y -qq
sudo apt-get install -qq -y kubeadm kubelet kubectl
# sudo apt-get install -qq -y kubelet="$KUBERNETES_VERSION" kubectl="$KUBERNETES_VERSION" kubeadm="$KUBERNETES_VERSION"
sudo apt-get update -y
sudo apt-get install -y jq
echo "Installed kubelet kubectl kubeadm"

# Disable auto-update services
sudo apt-mark hold kubelet kubectl kubeadm cri-o

echo 'vagrant ALL=(ALL) NOPASSWD:ALL' | sudo tee -a /etc/sudoers
echo 'Defaults:vagrant !requiretty' | sudo tee -a /etc/sudoers

local_ip="$(ip --json a s | jq -r '.[] | if .ifname == "eth1" then .addr_info[] | if .family == "inet" then .local else empty end else empty end')"
cat > /etc/default/kubelet << EOF
KUBELET_EXTRA_ARGS=--node-ip=$local_ip
${ENVIRONMENT}
EOF

# <<com
# # enable ssh password authentication
# sed -i 's/^PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
# echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
# systemctl reload sshd
# echo "Enabled ssh password authentication"

# # set root password"
# echo -e "kubeadmin\nkubeadmin" | passwd root >/dev/null 2>&1
# echo "export TERM=xterm" >> /etc/bash.bashrc
# echo "Set root password as kubeadmin"
# com

# # extra add sources
# sudo chmod o+r /etc/resolv.conf
# sudo sed -i 's/in\./us\./g' /etc/apt/sources.list
# sudo systemctl restart systemd-resolved
# echo "Extra add sources"

# # enable dmesg for debugging
# echo 'kernel.dmesg_restrict=0' | sudo tee -a /etc/sysctl.d/99-sysctl.conf
# sudo service procps restart
# echo "Enable dmesg for debugging"

# # added kubelet args to show actual ip address 
# KEA=Environment=\"KUBELET_EXTRA_ARGS=--node-ip=`ip addr show enp0s8 | grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}" | head -1`\"
# sed -i "4 a $KEA" /usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf
# sudo systemctl daemon-reload && sudo systemctl restart kubelet
# echo "Added kubelet args to show actual ip address"

# if [ "$RUNTIME" = "containerd" ]; 
# then
#   # set download latest crictl
#   CTLVERSION=$(curl -s https://api.github.com/repos/kubernetes-sigs/cri-tools/releases/latest | grep "tag_name" | cut -d '"' -f 4)

#   sudo wget -q https://github.com/kubernetes-sigs/cri-tools/releases/download/$CTLVERSION/crictl-$CTLVERSION-linux-amd64.tar.gz
#   sudo tar zxvf crictl-$CTLVERSION-linux-amd64.tar.gz -C /usr/local/bin
#   rm -f crictl-$CTLVERSION-linux-amd64.tar.gz

#   sudo crictl config --set runtime-endpoint=unix:///run/containerd/containerd.sock
#   sudo crictl --version
# fi

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