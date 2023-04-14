#!/bin/bash

IMAGE_UPDATE=(
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
    echo "ContainerId | ImageId | RepoTags"
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
        image_info=$(docker inspect $imageid --format="{{index .RepoTags 0}}" 2>/dev/null)
        echo "$container_info $image_info"
      fi
    done
  elif [ "$CMD" = "tools" ]; then
    # tools=("tcpdump" "sniffer" "wireshark" "Netcat" "gdb" "strace" "readelf" "cpp" "gcc" "dexdump" "mirror" "JDK" "netcat")
    tools=("tcpdump" "sniffer" "wireshark" "Netcat" "strace" "readelf" "Nmap" "gdb" "cpp" "gcc" "jdk" "javac" "make" "binutils" "flex" "glibc-devel" "gcc-c++" "Id" "lex" "rpcgen" "objdump" "eu-readelf" "eu-objdump" "dexdump" "mirror" "lua" "Perl")
    echo "tool | Id | RepoTags"
    # shellcheck disable=SC2068
    for tool in ${tools[@]}; do
#      echo "$tool"
      # shellcheck disable=SC2046
      # shellcheck disable=SC1066
      overlays=$(find /var/lib/docker | grep -i "/${tool}$" | awk -F/ '{print $6}' | uniq | sort | grep -v "^$")
      if [ "$overlays" = "" ]; then
        continue
      fi
#      image=$(docker image ls | awk '{if (NR>1){print $3}}' | \
#              xargs docker inspect --format '{{.Id}} {{.GraphDriver.Data}}' 2>/dev/null | \
#              grep -E $(echo $overlays | sed 's/ /|/g') | awk '{print $1}')
#      echo $(find $(docker inspect "${image}" -f {{.GraphDriver.Data.UpperDir}}) 2>/dev/null| grep -i "/${tool}$")

      docker image ls | awk '{if (NR>1){print $3}}' | \
      xargs docker inspect --format '{{.Id}}, {{index .RepoTags 0}}, {{.GraphDriver.Data}}' 2>/dev/null | \
      grep -E $(echo $overlays | sed 's/ /|/g') | awk -F, '{printf("%s %s %s\n", "'$tool'", $1, $2)}'
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
  elif [ "$CMD" = "permission" ]; then
    images=$(docker image ls | awk 'NR!=1 {print $3}')
    echo "image | permission | file"
    # shellcheck disable=SC2068
    for image in ${images[@]}; do
      # shellcheck disable=SC2005
      repo_tags=$(docker inspect $image --format="{{index .RepoTags 0}}" 2>/dev/null)
      # shellcheck disable=SC2086
      docker inspect "${image}" -f {{.GraphDriver.Data.UpperDir}} | awk -F ":" 'BEGIN{OFS="\n"}{ for(i=1;i<=NF;i++)printf("%s\n",$i)}' | xargs -I {} find {} ! -perm 600 -name "*.crt" -o ! -perm 600 -name "*.pem" -o ! -perm 600 -name "*.conf" -ls 2>/dev/null | awk '{printf("%s %s %s %s\n","'$image'", "'$repo_tags'", $3, $11)}'
      docker inspect "${image}" -f {{.GraphDriver.Data.LowerDir}} | awk -F ":" 'BEGIN{OFS="\n"}{ for(i=1;i<=NF;i++)printf("%s\n",$i)}' | xargs -I {} find {} ! -perm 600 -name "*.crt" -o ! -perm 600 -name "*.pem" -o ! -perm 600 -name "*.conf" -ls 2>/dev/null | awk '{printf("%s %s %s %s\n","'$image'", "'$repo_tags'", $3, $11)}'
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
    # shellcheck disable=SC2128
    repo=${repo:-dockerhub.kubekey.local/huawei}
    # shellcheck disable=SC2068
    for image in ${IMAGE_UPDATE[@]}; do
      docker pull "$repo/$image" && docker save "$repo/$image" -o "$image.tar.gz"
    done
  elif [ "$CMD" = "load_images" ]; then
    # shellcheck disable=SC2128
    repo=${repo:-dockerhub.kubekey.local/huawei}
    sep=${sep:-:}
    local=${local:-flase}
    # shellcheck disable=SC2068
    for image in ${IMAGE_UPDATE[@]}; do
      if [ $local = true ]; then
        image_name=$(ls -l | grep $(echo $image | awk -F : '{print $1:$2}') | awk '{print $9}')
        if [ "$image_name" = "" ]; then
          echo "$image not found"
          continue
        fi
        filename="$image_name"
      else
        # shellcheck disable=SC2001
        filename=$(echo "$image.tar.gz" | sed "s/:/$sep/")
      fi
      if [ -f "$filename" ]; then
        image_tag=$(docker load -i "$filename" | awk '{print $3}')
        # shellcheck disable=SC2154
        docker tag "$image_tag" "$repo/$image"
        docker push "$repo/$image"
      else
        echo "$filename not found"
      fi
    done
  elif [ "$CMD" = "pull" ]; then
    # shellcheck disable=SC2128
    repo=${repo:-dockerhub.kubekey.local/huawei}
    # shellcheck disable=SC2068
    for image in ${IMAGE_UPDATE[@]}; do
      docker pull "$repo/$image"
    done
  fi
}

utils $1 $2
