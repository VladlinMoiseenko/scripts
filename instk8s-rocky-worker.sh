#!/usr/bin/env bash

echo "SELINUX=permissive"
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

echo "Set module"
modprobe overlay
modprobe br_netfilter

cat > /etc/modules-load.d/k8s.conf << EOF
overlay
br_netfilter
EOF

cat > /etc/sysctl.d/k8s.conf << EOF
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

sysctl --system

echo "Swap off"
swapoff -a
sed -e '/swap/s/^/#/g' -i /etc/fstab

echo "Install Containerd"
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
dnf makecache
dnf install -y containerd.io
mv /etc/containerd/config.toml /etc/containerd/config.toml.orig
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false$/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl enable --now containerd.service

echo "Set firewall"
firewall-cmd --permanent --add-port={10250,30000-32767}/tcp
firewall-cmd --reload

echo "Install k8s"
cat > /etc/yum.repos.d/k8s.repo << EOF
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl
EOF

dnf makecache
dnf install -y {kubelet,kubeadm,kubectl} --disableexcludes=kubernetes

systemctl enable --now kubelet.service

echo "Set bash_completion"
source <(kubectl completion bash)
kubectl completion bash > /etc/bash_completion.d/kubectl

echo "Install Flannel CNI"
mkdir /opt/bin 
curl -fsSLo /opt/bin/flanneld https://github.com/flannel-io/flannel/releases/download/v0.20.1/flannel-v0.20.1-linux-amd64.tar.gz
chmod +x /opt/bin/flanneld

echo "exit 0"
exit 0