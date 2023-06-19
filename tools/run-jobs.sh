#!/bin/bash

if [ ${debug:-false} = true ]; then
  set -x
fi

target=${target:-192.168.200.2 192.168.200.3 192.168.200.4 192.168.200.5 192.168.200.6 192.168.200.7}

hostname=$(sh -c hostname)
node_ip=$(kubectl get node -o wide | grep "$hostname" | awk '{print $6}')
if [ "$node_ip" = "" ]; then
  return
fi

# shellcheck disable=SC2068
for elem in ${target[@]}; do
  if [ "$elem" = "$node_ip" ]; then
    continue
  fi
  scp image-check.sh security-account.sh "root@$elem:/root/"
done

function batch_run() {
  # shellcheck disable=SC2068
  for elem in ${target[@]}; do
    if [ "$elem" = "$node_ip" ]; then
      continue
    fi
    ssh -q "root@$elem" $1
  done
}

function dump_root_containers {
  ./image-check.sh root
  batch_run "/root/image-check.sh root"
}

function dump_tools_containers {
  ./image-check.sh tools
  batch_run "/root/image-check.sh tools"
}

function dump_envs_containers {
  ./image-check.sh env
  batch_run "/root/image-check.sh env"
}

function dump_permission_file_images {
  ./image-check.sh permission
  batch_run "/root/image-check.sh permission"
}

function dump_api_access_token_containers {
  ./image-check.sh token
  batch_run "/root/image-check.sh token"
}

function dump_openssl_containers {
  ./image-check.sh openssl
  batch_run "/root/image-check.sh openssl"
}

function clean_image_unused() {
  ./image-check.sh clean
  batch_run "/root/image-check.sh clean"
}

function dump_system_account() {
  ./security-account.sh
  batch_run "/root/security-account.sh"
}

CMD=$1

if [ "$CMD" = "root" ]; then
  dump_root_containers
elif [ "$CMD" = "tools" ]; then
  dump_tools_containers
elif [ "$CMD" = "env" ]; then
  dump_envs_containers
elif [ "$CMD" = "permission" ]; then
  dump_permission_file_images
elif [ "$CMD" = "token" ]; then
  dump_api_access_token_containers
elif [ "$CMD" = "openssl" ]; then
  dump_openssl_containers
elif [ "$CMD" = "account" ]; then
  dump_system_account
elif [ "$CMD" = "clean" ]; then
  clean_image_unused
fi
