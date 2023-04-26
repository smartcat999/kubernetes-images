#!/bin/bash

# 1. 检查privileged特权容器
# ./image-check.sh privileged

# 2. 检查root用户容器
# ./image-check.sh root

# 3. 检查包含调试/嗅探工具的镜像
# ./image-check.sh tools

# 4. 检查环境变量中含有敏感信息的容器
# ./image-check.sh env

# 5. 检查配置文件/证书文件权限不是600的镜像
# ./image-check.sh permission

# 6. 检查挂载k8s token的容器
# ./image-check.sh token

# 7. 检查容器本身的证书私钥 以及 挂载的私钥是否加密
# ./image-check.sh openssl

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
      # shellcheck disable=SC2046
      # shellcheck disable=SC1066
      overlays=$(find /var/lib/docker | grep -i "/${tool}$" | awk -F/ '{print $6}' | uniq | sort | grep -v "^$")
      if [ "$overlays" = "" ]; then
        continue
      fi

      docker image ls | awk '{if (NR>1){print $3}}' |
        xargs docker inspect --format '{{.Id}}, {{index .RepoTags 0}}, {{.GraphDriver.Data}}' 2>/dev/null |
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
    hostname=$(sh -c hostname)
    images=$(docker image ls | awk 'NR!=1 {print $3}')
    echo "hostname | image | permission | file"
    # shellcheck disable=SC2068
    for image in ${images[@]}; do
      # shellcheck disable=SC2005
      repo_tags=$(docker inspect $image --format="{{index .RepoTags 0}}" 2>/dev/null)
      # shellcheck disable=SC2086
      docker inspect "${image}" -f {{.GraphDriver.Data.UpperDir}} | awk -F ":" 'BEGIN{OFS="\n"}{ for(i=1;i<=NF;i++)printf("%s\n",$i)}' |
        xargs -I {} find {} ! -perm 600 -name "*.crt" -o ! -perm 600 -name "*.pem" -o ! -perm 600 -name "*.conf" 2>/dev/null |
        xargs -I {} ls -l {} | awk -F ' ' '{if (NR>1) {printf("%s %s %s %s %s\n", "'$hostname'", "'$image'", "'$repo_tags'", $1, $9)}}'
      # shellcheck disable=SC2086
      docker inspect "${image}" -f {{.GraphDriver.Data.LowerDir}} | awk -F ":" 'BEGIN{OFS="\n"}{ for(i=1;i<=NF;i++)printf("%s\n",$i)}' |
        xargs -I {} find {} ! -perm 600 -name "*.crt" -o ! -perm 600 -name "*.pem" -o ! -perm 600 -name "*.conf" 2>/dev/null |
        xargs -I {} ls -l {} | awk -F ' ' '{if (NR>1) {printf("%s %s %s %s %s\n", "'$hostname'", "'$image'", "'$repo_tags'", $1, $9)}}'
    done
  elif [ "$CMD" = "token" ]; then
    token_dirs=$(find / -name "kube-api-access-*" 2>/dev/null)
    hostname=$(sh -c hostname)
    node_ip=$(kubectl get node -o wide | awk '{if (NR==2){print $6}}')
    if [ "$node_ip" = "" ]; then
      return
    fi
    server=${server:-https://$node_ip:6443}
    echo "hostname | token | containers"
    # shellcheck disable=SC2068
    for token_dir in ${token_dirs[@]}; do
      token="$token_dir/token"
      container_dir=$(echo "$token_dir" | awk -F "/" '{for(i=1;i<7;i++) printf("%s/",$i)}')
      # shellcheck disable=SC2012
      containers=$(ls "$container_dir"/containers | awk '{for(i=1;i<4;i++) if($i!="")printf("%s ",$i)}')
      echo "$hostname $token $containers"
      # shellcheck disable=SC2046
      kubectl --token=$(cat "$token") --kubeconfig=/dev/null --server="${server}" --insecure-skip-tls-verify=true auth can-i --list
    done
  elif [ "$CMD" = "openssl" ]; then
    hostname=$(sh -c hostname)
    echo " hostname | image | tag | container | file"
    containers=$(docker ps | awk 'NR!=1 {print $1}')
    # shellcheck disable=SC2068
    for container in ${containers[@]}; do
      # shellcheck disable=SC2046
      # shellcheck disable=SC1066
      container_info=$(docker ps --format="{{.ID}}  {{.Image}}  {{.Names}}" | grep "$container")
      image=$(docker ps | grep "$container" | awk '{print $2}')
      repo_tags=$(docker inspect "$image" --format="{{index .RepoTags 0}}" 2>/dev/null)
      mounts=$(docker inspect "$container" -f '{{range .Mounts}}{{printf "%s\n" .Source}}{{end}}')

      # shellcheck disable=SC2034
      for mount_dir in ${mounts[@]}; do
        if [[ $mount_dir = "/proc" ]] || [[ $mount_dir = "/sys" ]] || [[ $mount_dir = "/" ]]; then
          continue
        fi
        mount_files=$(find "$mount_dir" -name "*.key")
        for mount_file in ${mount_files[@]}; do
          is_encrypted=$(grep -c "BEGIN ENCRYPTED PRIVATE KEY" "$mount_file")
          if [[ $is_encrypted = '1' ]]; then
            continue
          else
            echo "$hostname $image, $repo_tags, $container, $mount_file"
          fi
        done
      done

      upper_files=$(docker inspect "$container" -f {{.GraphDriver.Data.UpperDir}} | sed 's/:/\n/g' | xargs -I {} find {} -name "*.key" 2>/dev/null)
      if [[ $upper_files != "" ]]; then
        for upper_file in ${upper_files[@]}; do
          is_encrypted=$(grep -c "BEGIN ENCRYPTED PRIVATE KEY" "$upper_file")
          if [[ $is_encrypted = '1' ]]; then
            continue
          else
            echo "$hostname $image, $repo_tags, $container, $upper_file"
          fi
        done
      fi
      lower_files=$(docker inspect "$container" -f {{.GraphDriver.Data.LowerDir}} | sed 's/:/\n/g' | xargs -I {} find {} -name "*.key" 2>/dev/null)
      if [[ $lower_files != "" ]]; then
        for lower_file in ${lower_files[@]}; do
          is_encrypted=$(grep -c "BEGIN ENCRYPTED PRIVATE KEY" "$lower_file")
          if [[ $is_encrypted = '1' ]]; then
            continue
          else
            echo "$hostname $image, $repo_tags, $container, $lower_file"
          fi
        done
      fi

    done
  fi
}

utils $1 $2
