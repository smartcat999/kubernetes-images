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
  scp image-check.sh "root@$elem:/root/"
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

function pull_update_images {
  ./image-check.sh pull
  batch_run "/root/image-check.sh pull"
}

function dump_permission_file_images {
  ./image-check.sh permission
  batch_run "/root/image-check.sh permission"
}

function dump_api_access_token_containers {
  ./image-check.sh token
  batch_run "/root/image-check.sh token"
}

function clean_image_unused() {
  docker system prune -a -f
  batch_run "docker system prune -a -f"
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
elif [ "$CMD" = "pull" ]; then
  pull_update_images
elif [ "$CMD" = "clean" ]; then
  clean_image_unused
fi
