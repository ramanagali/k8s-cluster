# change docker to containerd
kubectl drain $(hostname -s) --ignore-daemonsets

#stop the servcie
sudo systemctl stop kubelet
sudo systemctl disable docker.service --now

# update kubletargs & annotate node
echo "KUBELET_KUBEADM_ARGS=\"--cgroup-driver=systemd --network-plugin=cni --pod-infra-container-image=k8s.gcr.io/pause:3.6
--resolv-conf=/run/systemd/resolve/resolv.conf --container-runtime=remote --container-runtime-endpoint=unix:///run/containerd/containerd.sock\"" | sudo tee /var/lib/kubelet/kubeadm-flags.env
kubectl annotate no $(hostname -s) kubeadm.alpha.kubernetes.io/cri-socket=unix=///run/containerd/containerd.sock --overwrite

sudo swapoff -a && sudo systemctl start kubelet
kubectl uncordon $(hostname -s)
sleep 5

#remove docker
sudo apt purge -y docker-ce docker-ce-cli
 
echo "Migrated from docker to containerd"