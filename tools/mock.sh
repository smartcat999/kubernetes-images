#!/usr/bin/env bash

if [ ${debug:-false} = true ]; then
  set -x
fi

function message() {
  # echo -e "\033[字背景颜色；文字颜色m字符串\033[0m"
  echo -e "\033[32m$1\033[0m"
}

function error() {
  echo -e "\033[31m$1\033[0m"
}

KS_APISERVER=""
MEMBER_CLUSTER=""
USER=""
PASS=""
if [ "$USER" = "" ]; then
  error "Please set USER=user PASS=*** !"
  exit 1
fi

function discover-ks-apiserver() {
  apiserver=$(kubectl -n kubesphere-system get pods -o wide -l app=ks-apiserver | awk '{if ( NR>1 ) print $6 }')
  export KS_APISERVER=http://$apiserver:9090
}

function oauth() {
  token=$(curl --location "$KS_APISERVER/oauth/token" \
    --header "Content-Type: application/x-www-form-urlencoded" \
    --data-urlencode "username=$USER" \
    --data-urlencode "password=$PASS" \
    --data-urlencode "client_id=kubesphere" \
    --data-urlencode "grant_type=password" \
    --data-urlencode "client_secret=kubesphere" | jq .access_token | sed 's/"//g')
  export KS_TOKEN=$token
}

# init api info/token
discover-ks-apiserver
oauth

echo KS_APISERVER: $KS_APISERVER
echo KS_TOKEN: $KS_TOKEN

function create-nodegroup() {
  nodegroup=$1
  message "create-nodegroup: $nodegroup"
  url="$KS_APISERVER/kapis/infra.kubesphere.io/v1alpha1/nodegroups"
  if [ "$MEMBER_CLUSTER" != "" ]; then
    url="$KS_APISERVER/kapis/clusters/$MEMBER_CLUSTER/infra.kubesphere.io/v1alpha1/nodegroups"
  fi

  curl --location $url \
    --header 'Content-Type: application/json' \
    --header "Authorization: Bearer $KS_TOKEN" \
    --data '{
      "apiVersion": "infro.kubesphere.io/v1alpha1",
      "kind": "NodeGroup",
      "metadata": {
          "name": "'"$nodegroup"'"
      },
      "spec": {
          "alias": "'"$nodegroup"'",
          "description": "'"$nodegroup"'"
      }
  }'
}

function delete-nodegroup() {
  nodegroup=$1
  message "delete-nodegroup: $nodegroup"
  if [ "$MEMBER_CLUSTER" != "" ]; then
    url="$KS_APISERVER/kapis/clusters/$MEMBER_CLUSTER/infra.kubesphere.io/v1alpha1/nodegroups/$nodegroup"
  fi
  url="$KS_APISERVER/kapis/infra.kubesphere.io/v1alpha1/nodegroups/$nodegroup"
  curl --location --request DELETE $url \
    --header "Authorization: Bearer $KS_TOKEN"
}

function create-vnode() {
  node=$1
  message "create-vnode: $node"
  cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Node
metadata:
  annotations:
    node.alpha.kubernetes.io/ttl: "0"
    volumes.kubernetes.io/controller-managed-attach-detach: "true"
  labels:
    beta.kubernetes.io/arch: amd64
    beta.kubernetes.io/os: linux
    kubernetes.io/arch: amd64
    kubernetes.io/hostname: $node
    kubernetes.io/os: linux
    node-role.kubernetes.io/control-plane: ""
    node-role.kubernetes.io/master: ""
    node-role.kubernetes.io/worker: ""
    node.kubernetes.io/exclude-from-external-load-balancers: ""
    vnode: "mock"
  name: $node
spec: {}
status: {}
EOF
}

function delete-vnode() {
  echo "delete-vnode"
  kubectl get nodes -l vnode=mock | awk '{if (NR>1) print $1}' | xargs kubectl delete node
}

case "$1" in
"create")
  for ((i = 1; i < 10; i++)); do
    create-nodegroup nodegroup0$i
    create-vnode vnode0$i
  done
  ;;
"clean")
  for ((i = 1; i < 10; i++)); do
    delete-nodegroup nodegroup0$i
  done
  delete-vnode
  ;;
esac
