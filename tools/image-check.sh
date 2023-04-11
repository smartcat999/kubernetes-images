#!/bin/bash

#set -x
function utils {
  if [ ${debug:-false} = true ]; then
    set -x
  fi

  CMD=$1
  if [ "$CMD" = "privileged" ]; then
    docker ps --quiet -a | xargs docker inspect --format='{{.Name}} {{.HostConfig.Privileged}}' | grep true | awk '{print $1}'

  elif [ "$CMD" = "root" ]; then
    containers=$(docker ps | awk 'NR!=1 {print $1}')
    # shellcheck disable=SC2154
    #  echo $containers
    # shellcheck disable=SC2068
    for container in ${containers[@]}; do
      # echo $image
      # shellcheck disable=SC2046
      # shellcheck disable=SC1066
      user=$(docker exec -i "$container" whoami)
      if [ $? != 0 ]; then
        continue
      fi
      if [ "$user" = "root" ]; then
        container_info=$(docker ps --format="{{.ID}}  {{.Image}}  {{.Names}}" | grep "$container")
        imageid=$(docker ps | grep "$container" | awk '{print $2}')
        image_info=$(docker inspect $imageid --format="{{index .RepoTags 0}}")
        echo "$container_info $image_info"
      fi
    done
  elif [ "$CMD" = "tools" ]; then
    # tools=("tcpdump" "sniffer" "wireshark" "Netcat" "gdb" "strace" "readelf" "cpp" "gcc" "dexdump" "mirror" "JDK" "netcat")
    tools=("tcpdump" "sniffer" "wireshark" "Netcat" "strace" "readelf" "Nmap" "gdb" "cpp" "gcc" "jdk" "javac" "make" "binutils" "flex" "glibc-devel" "gcc-c++" "Id" "lex" "rpcgen" "objdump" "eu-readelf" "eu-objdump" "dexdump" "mirror" "lua" "Perl")
    # shellcheck disable=SC2068
    for tool in ${tools[@]}; do
      echo "$tool"
      # shellcheck disable=SC2046
      # shellcheck disable=SC1066
      overlays=$(find /var/lib/docker | grep -i "/${tool}$" | awk -F/ '{print $6}' | uniq | sort | grep -v "^$")
      if [ "$overlays" = "" ]; then
        continue
      fi
      docker image ls | awk '{if (NR>1){print $3}}' | xargs docker inspect --format '{{.Id}}, {{.RepoTags}}, {{.GraphDriver.Data}}' | grep -E $(echo $overlays | sed 's/ /|/g') | awk -F, '{print $1 $2}'
      # shellcheck disable=SC2181
      if [ $? != 0 ]; then
        continue
      fi
    done
  elif [ "$CMD" = "env" ]; then
    containers=$(docker ps | awk 'NR!=1 {print $1}')
    # shellcheck disable=SC2068
    for container in ${containers[@]}; do
      # echo $image
      # shellcheck disable=SC2046
      # shellcheck disable=SC1066
      container_info=$(docker ps --format="{{.ID}}  {{.Image}}  {{.Names}}" | grep "$container")
      envs=$(docker inspect "$container" --format="{{.Config.Env}}")
      # shellcheck disable=SC2046
      if [ "$(echo "$envs" | grep -i "password\|secret\|token")" = "" ]; then
        continue
      fi
      imageid=$(docker ps | grep "$container" | awk '{print $2}')
      image_info=$(docker inspect "$imageid" --format="{{index .RepoTags 0}}")
      # shellcheck disable=SC2181
      if [ $? = 0 ]; then
        echo "$container_info $image_info $envs"
      else
        echo "$container_info $imageid $envs"
      fi
    done
  elif [ "$CMD" = "save" ]; then
    image=$2
    repo=${repo:-dockerhub.kubekey.local/huawei}
    docker pull "$repo/$image" && docker save "$repo/$image" -o "$image.tar.gz"
  elif [ "$CMD" = "load" ]; then
    image=$2
    repo=${repo:-dockerhub.kubekey.local/huawei}
    docker load -i "$image.tar.gz" && docker push "$repo/$image"
  elif [ "$CMD" = "save_images" ]; then
    images=(
      alertmanager:v0.23.0
      configmap-reload:v0.5.0
      node-exporter:v1.3.1
      prometheus-config-reloader:v0.55.1
      prometheus-operator:v0.55.1
      prometheus:v2.35.0
      redis-arm:v6.2.5
      redis-exporter-arm:v1.44.0
      thanos:v0.26.0
    )
    repo=${repo:-dockerhub.kubekey.local/huawei}
    # shellcheck disable=SC2068
    for image in ${images[@]}; do
      docker pull "$repo/$image" && docker save "$repo/$image" -o "$image.tar.gz"
    done
  elif [ "$CMD" = "load_images" ]; then
    images=(
          alertmanager:v0.23.0
          configmap-reload:v0.5.0
          node-exporter:v1.3.1
          prometheus-config-reloader:v0.55.1
          prometheus-operator:v0.55.1
          prometheus:v2.35.0
          redis-arm:v6.2.5
          redis-exporter-arm:v1.44.0
          thanos:v0.26.0
    )
    repo=${repo:-dockerhub.kubekey.local/huawei}
    # shellcheck disable=SC2068
    for image in ${images[@]}; do
        docker load -i "$image.tar.gz" && docker push "$repo/$image"
    done
  fi
}

utils $1 $2
