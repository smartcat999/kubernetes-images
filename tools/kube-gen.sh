#!/usr/bin/env bash

# Add new node ip to kubeconfig
# Usage: kube-gen.sh $MASTER_IP
set -x

MASTER_IP=$1
MASTER_PORT=${2:-'6443'}

echo "Prepare add new server ip $MASTER_IP:$MASTER_PORT"

cp -r /etc/kubernetes{,-bak}
echo "Backup /etc/kubernetes finished"

rm /etc/kubernetes/pki/apiserver.*
echo "Remove /etc/kubernetes/pki/apiserver.*"

APISERVER=$(cat /etc/kubernetes/manifests/kube-apiserver.yaml |grep '\-\-advertise-address' | awk -F"=" '{print $2}')
echo "APISERVER_ADVERTISE_ADDRESS: $APISERVER"

kubeadm init phase certs apiserver --apiserver-advertise-address ${APISERVER} --apiserver-cert-extra-sans ${MASTER_IP}

cd /etc/kubernetes/pki && kubeadm certs renew admin.conf
echo "Regenerate cert finished"
echo "Sleep 5s"
sleep 5s

echo "Restart kube-apiserver && sleep 5s"
mv /etc/kubernetes/manifests/kube-apiserver.yaml /etc/kubernetes/
sleep 5s
mv /etc/kubernetes/kube-apiserver.yaml /etc/kubernetes/manifests/kube-apiserver.yaml

echo "Update ~/.kube/config"
cp /etc/kubernetes/admin.conf $HOME/.kube/config

cluster=$(cat $HOME/.kube/config |grep "  cluster:" | awk -F ': ' '{print $2}')
echo "Update cluster: $cluster server: https://${MASTER_IP}:${MASTER_PORT}"
kubectl config set clusters.$cluster.server https://${MASTER_IP}:${MASTER_PORT} --kubeconfig=$HOME/.kube/config

echo "Please wait for the kube-apiserver to restart"
echo "You can look at this kubeconfig with 'cat $HOME/.kube/config'"