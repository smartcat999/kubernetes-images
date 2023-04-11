#!/bin/bash

target=${target:-192.168.200.3 192.168.200.4 192.168.200.5 192.168.200.6 192.168.200.7}
# shellcheck disable=SC2068
for elem in ${target[@]}; do
  scp image-check.sh "root@$elem:/root/"
done

function dump_root_containers {
  # shellcheck disable=SC2068
  for elem in ${target[@]}; do
    ssh "root@$elem" "/root/image-check.sh root"
  done
}

function dump_tools_containers {
  # shellcheck disable=SC2068
  for elem in ${target[@]}; do
    ssh "root@$elem" "/root/image-check.sh tools"
  done
}

function dump_envs_containers {
  # shellcheck disable=SC2068
  for elem in ${target[@]}; do
    ssh "root@$elem" "/root/image-check.sh env"
  done
}

function pull_update_images {
  # shellcheck disable=SC2068
  for elem in ${target[@]}; do
    ssh "root@$elem" "/root/image-check.sh pull"
  done
}


CMD=$1

if [ "$CMD" = "root" ]; then
  dump_root_containers
elif [ "$CMD" = "tools" ]; then
  dump_tools_containers
elif [ "$CMD" = "env" ]; then
  dump_envs_containers
elif [ "$CMD" = "pull" ]; then
  pull_update_images
fi