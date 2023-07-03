#!/usr/bin/env bash

: ${USE_SUDO:="true"}

HAS_KUBECTL="$(type "kubectl" &> /dev/null && echo true || echo false)"

runAsRoot() {
  if [ $EUID -ne 0 -a "$USE_SUDO" = "true" ]; then
    sudo "${@}"
  else
    "${@}"
  fi
}

echo 'Install kubelet kubeadm kubectl'
if [ "${HAS_KUBECTL}" != "true" ]; then
  runAsRoot apt -y install curl apt-transport-https
  curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | runAsRoot apt-key add -
  echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | runAsRoot tee /etc/apt/sources.list.d/kubernetes.list
  runAsRoot apt update
  runAsRoot apt -y install vim git curl wget kubelet kubeadm kubectl
  runAsRoot apt-mark hold kubelet kubeadm kubectl
fi

echo 'Disable swap'
runAsRoot sed -i 's/\/swap.img/\#swap.img/g' /etc/fstab
runAsRoot swapoff -a
runAsRoot mount -a

echo 'Enable kernel modules'
runAsRoot modprobe overlay
runAsRoot modprobe br_netfilter

runAsRoot tee /etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

runAsRoot sysctl --system

echo 'Install Containerd'
runAsRoot tee /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF

runAsRoot modprobe overlay
runAsRoot modprobe br_netfilter

runAsRoot tee /etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

runAsRoot sysctl --system

runAsRoot apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates

echo 'Add Docker repo'
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | runAsRoot apt-key add -
runAsRoot add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

runAsRoot apt update
runAsRoot apt install -y containerd.io

runAsRoot mkdir -p /etc/containerd
runAsRoot chown $USER:$USER /etc/containerd/config.toml
runAsRoot containerd config default>/etc/containerd/config.toml

echo 'Restart containerd'
runAsRoot systemctl restart containerd
runAsRoot systemctl enable containerd

echo 'Initialize master node'
runAsRoot systemctl enable kubelet

runAsRoot kubeadm config images pull

runAsRoot kubeadm config images pull --cri-socket unix:///run/containerd/containerd.sock

runAsRoot sysctl -p

echo 'Bootstrap without shared endpoint'
runAsRoot kubeadm init \
--pod-network-cidr=172.24.0.0/16 \
--cri-socket unix:///run/containerd/containerd.sock

mkdir -p $HOME/.kube
runAsRoot cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
runAsRoot chown $(id -u):$(id -g) $HOME/.kube/config

echo 'Install Calico CNI'
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.1/manifests/tigera-operator.yaml
curl https://raw.githubusercontent.com/projectcalico/calico/v3.25.1/manifests/custom-resources.yaml -O

kubectl create -f custom-resources.yaml
kubectl taint nodes --all  node-role.kubernetes.io/control-plane-
kubectl apply -f https://docs.projectcalico.org/v3.14/manifests/calico.yaml

exit 0