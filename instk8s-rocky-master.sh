#!/usr/bin/env bash

hostnamectl set-hostname kubemaster-01.centlinux.com

echo 192.168.247.147 kubemaster-01.centlinux.com kubemaster-01 >> /etc/hosts

dnf makecache --refresh

dnf update -y

reboot

echo "exit 0"
exit 0