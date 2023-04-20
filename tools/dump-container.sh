#!/bin/bash

target=${target:-192.168.200.3 192.168.200.4 192.168.200.5 192.168.200.6 192.168.200.7}
# shellcheck disable=SC2068
for elem in ${target[@]}; do
  scp image-check.sh "root@$elem:/root/"
done

function dump_root_containers {
  ./image-check.sh root
  # shellcheck disable=SC2068
  for elem in ${target[@]}; do
    ssh -q "root@$elem" "/root/image-check.sh root"
  done
}

function dump_tools_containers {
  ./image-check.sh tools
  # shellcheck disable=SC2068
  for elem in ${target[@]}; do
    ssh -q "root@$elem" "/root/image-check.sh tools"
  done
}

function dump_envs_containers {
  ./image-check.sh env
  # shellcheck disable=SC2068
  for elem in ${target[@]}; do
    ssh -q "root@$elem" "/root/image-check.sh env"
  done
}

function pull_update_images {
  ./image-check.sh pull
  # shellcheck disable=SC2068
  for elem in ${target[@]}; do
    ssh -q "root@$elem" "/root/image-check.sh pull"
  done
}


function dump_permission_file_images {
  ./image-check.sh permission
  # shellcheck disable=SC2068
  for elem in ${target[@]}; do
    ssh -q "root@$elem" "/root/image-check.sh permission"
  done
}


function dump_api_access_token_containers {
  ./image-check.sh token
  # shellcheck disable=SC2068
  for elem in ${target[@]}; do
    ssh -q "root@$elem" "/root/image-check.sh token"
  done
}

function clean_image_unused() {
    docker system prune -a -f
    # shellcheck disable=SC2068
    for elem in ${target[@]}; do
      ssh -q "root@$elem" "docker system prune -a -f"
    done
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