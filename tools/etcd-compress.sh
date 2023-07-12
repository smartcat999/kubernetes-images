#!/usr/bin/env bash

# etcd 数据碎片整理
# ./etcd-compress.sh
# cacert=/etc/ssl/etcd/ssl/ca.pem cert=/etc/ssl/etcd/ssl/node-ks02.pem key=/etc/ssl/etcd/ssl/node-ks02-key.pem endpoints=172.31.73.226:2379 ./etcd-compress.sh

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

export ETCDCTL_API=3
cacert=${cacert:-/etc/ssl/etcd/ssl/ca.pem}
cert=${cert:-/etc/ssl/etcd/ssl/node-smartcat-um773-se.pem}
key=${key:-/etc/ssl/etcd/ssl/node-smartcat-um773-se-key.pem}
endpoints=${endpoints:-172.31.189.234:2379}

CMD="etcdctl --endpoints=$endpoints --cacert $cacert --cert $cert --key $key"

$CMD endpoint status --write-out table

revision=$($CMD endpoint status --write-out json | jq .[0].Status.header.revision)
message "revision: $revision"

$CMD compact $revision
message "compact: $revision"

$CMD defrag
message "etcd defrag"

$CMD endpoint status --write-out table
