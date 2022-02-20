#! /bin/bash

# Install batcat - utility to view yaml files 
sudo apt install bat -y
mkdir -p ~/.local/bin
ln -s /usr/bin/batcat ~/.local/bin/bat

# kubebench
curl -L https://github.com/aquasecurity/kube-bench/releases/download/v0.6.5/kube-bench_0.6.5_linux_amd64.tar.gz -o kube-bench_0.6.5_linux_amd64.tar.gz
tar -xvf kube-bench_0.6.5_linux_amd64.tar.gz

# apparmor installed with ubunut 21:10
cat /sys/module/apparmor/parameters/enabled
cat /sys/kernel/security/apparmor/profiles
apt-get install apparmor-utils -y

# seccomp is part of kubernetes - no installation needed

# OPA Gatekeeper
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.7/deploy/gatekeeper.yaml

# gvisor-runsc
curl -fsSL https://gvisor.dev/archive.key | sudo gpg --dearmor -o /usr/share/keyrings/gvisor-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/gvisor-archive-keyring.gpg] https://storage.googleapis.com/gvisor/releases release main" | sudo tee /etc/apt/sources.list.d/gvisor.list > /dev/null

sudo add-apt-repository "deb [arch=amd64,arm64] https://storage.googleapis.com/gvisor/releases release main"

sudo apt-get update && sudo apt-get install -y runsc

cat <<EOF | sudo tee /etc/containerd/config.toml
version = 2
[plugins."io.containerd.runtime.v1.linux"]
  shim_debug = true
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
  runtime_type = "io.containerd.runc.v2"
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runsc]
  runtime_type = "io.containerd.runsc.v1"
EOF
sudo systemctl restart containerd

echo 0 > /proc/sys/kernel/dmesg_restrict
echo "kernel.dmesg_restrict=0" >> /etc/sysctl.conf
{
wget https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.13.0/crictl-v1.13.0-linux-amd64.tar.gz
tar xf crictl-v1.13.0-linux-amd64.tar.gz
sudo mv crictl /usr/local/bin
}

cat <<EOF | sudo tee /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
EOF
sudo systemctl restart containerd

# Install cfssl
sudo apt-get update -y
sudo apt-get install -y golang-cfssl

# trivy 
sudo apt-get install wget apt-transport-https gnupg lsb-release -y
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update -y 
sudo apt-get install trivy -y

# Install falco
sudo curl -s https://falco.org/repo/falcosecurity-3672BA8F.asc | apt-key add -
echo "deb https://download.falco.org/packages/deb stable main" | tee -a /etc/apt/sources.list.d/falcosecurity.list
sudo apt-get update -y
sudo apt-get -y install linux-headers-$(uname -r)
sudo apt-get install -y falco
echo "Installed Falco drivers"

# Falco as service - ondemand
# sudo systemctl start falco
# sudo systemctl enable falco

# Falco as helm daemonset
# helm repo add falcosecurity https://falcosecurity.github.io/charts
# helm repo update

# helm upgrade -i falco falcosecurity/falco \
#   --set falcosidekick.enabled=true \
#   --set falcosidekick.webui.enabled=true \
#   --set auditLog.enabled=true \
#   --set falco.jsonOutput=true \
#   --set falco.fileOutput.enabled=true