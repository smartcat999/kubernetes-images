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

# 8. 检查系统的无属组文件
# 不传path默认扫描 / 目录下的文件，不扫描 /proc 和 /sys
# ./image-check.sh noowner ${path}

#set -x
RUNTIME=${RUNTIME:-isula}
DOCKER_IMAGE_LS="docker image ls"
DOCKER_PS="docker ps"
DOCKER_INSPECT="docker inspect"
DOCKER_EXEC="docker exec"

if [ $RUNTIME = "isula" ]; then
  DOCKER_IMAGE_LS="isula images"
  DOCKER_PS="isula ps"
  DOCKER_INSPECT="isula inspect"
  DOCKER_EXEC="isula exec"
fi

function scan-privileged() {
  $DOCKER_PS --quiet -a | xargs $DOCKER_INSPECT --format='{{index .RepoTags 0}} {{.HostConfig.Privileged}}' 2>/dev/null | grep true | awk '{print $1}'
}

function scan-root() {
  containers=$($DOCKER_PS | awk 'NR!=1 {print $1}')
  # shellcheck disable=SC2154
  #  echo $containers
  echo "ContainerId | ImageId | RepoTags"
  # shellcheck disable=SC2068
  for container in ${containers[@]}; do
    # echo $image
    # shellcheck disable=SC2046
    # shellcheck disable=SC1066
    user=$($DOCKER_EXEC -i "$container" whoami 2>/dev/null)
    if [ $? != 0 ]; then
      continue
    fi
    if [ "$user" = "root" ]; then
      container_info=$($DOCKER_PS --format="{{.ID}}  {{.Image}}  {{.Names}}" | grep "$container" | awk '{print $1,$2}')
      imageid=$($DOCKER_PS | grep "$container" | awk '{print $2}')
      if [ "$RUNTIME" = "docker" ]; then
        image_info=$($DOCKER_INSPECT --format="{{index .RepoTags 0}}" $imageid 2>/dev/null)
      elif [ "$RUNTIME" = "isula" ]; then
        image_info=$($DOCKER_INSPECT -f {{.image.repo_tags}} $imageid | grep -Eo '[a-z\w]+[a-z0-9\w]+[^"]*')
      else
        image_info=""
      fi
      echo "$container_info $image_info"
    fi
  done
}

function scan-tools() {
  output="${1:-tools.txt}"
  # tools=("tcpdump" "sniffer" "wireshark" "Netcat" "gdb" "strace" "readelf" "cpp" "gcc" "dexdump" "mirror" "JDK" "netcat")
  tools=("tcpdump" "sniffer" "wireshark" "Netcat" "strace" "readelf" "Nmap" "gdb" "cpp" "gcc" "jdk" "javac" "make" "binutils" "flex" "glibc-devel" "gcc-c++" "Id" "lex" "rpcgen" "objdump" "eu-readelf" "eu-objdump" "dexdump" "mirror" "lua" "Perl")
  if [ $RUNTIME = "docker" ]; then
    echo "Tool | Id | RepoTags"
  else
    echo "Tool | Image | Path"
  fi
  # shellcheck disable=SC2068
  for tool in ${tools[@]}; do

    if [ $RUNTIME = "docker" ]; then
      # shellcheck disable=SC2046
      # shellcheck disable=SC1066
      overlays=$(find /var/lib/docker | grep -i "/${tool}$" | awk -F/ '{print $6}' | uniq | sort | grep -v "^$")
      if [ "$overlays" = "" ]; then
        continue
      fi

      result=$($DOCKER_IMAGE_LS | awk '{if (NR>1){print $3}}' |
        xargs $DOCKER_INSPECT --format '{{.Id}}, {{index .RepoTags 0}}, {{.GraphDriver.Data}}' 2>/dev/null |
        grep -E $(echo $overlays | sed 's/ /|/g') | awk -F, '{printf("%s %s %s\n", "'$tool'", $1, $2)}' 2>/dev/null)
      if [ "$result" != "" ]; then
        echo "$result" >>$output
      fi
    elif [ $RUNTIME = "isula" ]; then
      layer_dirs=$(find /var/lib/isulad/storage/overlay/ | grep diff$ | xargs -I {} find {} | grep -i "/${tool}$" | awk -F/ '{print $7}' | uniq | sort | grep -v "^$")
      if [ "$layer_dirs" = "" ]; then
        continue
      fi
      # shellcheck disable=SC2001
      layer_egrep=$(echo $layer_dirs | sed 's/ /|/g')

      root_dir=/var/lib/isulad/storage/overlay-images
      image_files=$(ls -l $root_dir | awk '{if (NR>1) print $9}')
      # shellcheck disable=SC2034
      for image_file in ${image_files[@]}; do
        image_dir=$root_dir/$image_file
        # shellcheck disable=SC2002
        image_json=$(cat "${image_dir}/images.json")
        image_id=$(echo $image_json| grep -Eo '"id": [^,]+' | awk '{print $2}' | sed 's/"//g')
        image_name=$(echo ${image_json} | grep -Eo '"names":[^,]+' | sed 's/ //g' | awk -F '"' '{print $4}')
        image_layer_file=$(find $image_dir | grep "=")
        layer_hashs=$(cat $image_layer_file | grep -Eo '"(sha256:[a-f0-9]+)"' | grep -E "'"${layer_egrep}"'")
        if [ "$layer_hashs" != "" ]; then
          for layer_hash in ${layer_hashs[@]}; do
            if [ "$image_name" != "" ]; then
              echo "$tool $image_name /var/lib/isulad/storage/overlay/$(echo $layer_hash | sed 's/"//g' | awk -F: '{print $2}')/diff/"
            else
              echo "$tool $image_id /var/lib/isulad/storage/overlay/$(echo $layer_hash | sed 's/"//g' | awk -F: '{print $2}')/diff/"
            fi
          done
        fi
      done
    fi
  done
  echo "output: $output"
}

function scan-env() {
  containers=$($DOCKER_PS | awk 'NR!=1 {print $1}')
  # shellcheck disable=SC2068
  for container in ${containers[@]}; do
    container_info=$($DOCKER_PS --format="{{.ID}}  {{.Image}}  {{.Names}}" | grep "$container")
    envs=$($DOCKER_INSPECT --format="{{.Config.Env}}" "$container")
    # shellcheck disable=SC2046
    if [ "$(echo "$envs" | grep -i "password\|secret\|token")" = "" ]; then
      continue
    fi
    imageid=$($DOCKER_PS | grep "$container" | awk '{print $2}')

    if [ "$RUNTIME" = "docker" ]; then
      image_info=$($DOCKER_INSPECT --format="{{index .RepoTags 0}}" $imageid 2>/dev/null)
    elif [ "$RUNTIME" = "isula" ]; then
      image_info=$($DOCKER_INSPECT -f {{.image.repo_tags}} $imageid | grep -Eo '[a-z\w]+[a-z0-9\w]+[^"]*')
    else
      image_info=""
    fi
    # shellcheck disable=SC2181
    if [ "$image_info" != "" ]; then
      echo "$container_info $image_info $envs"
    else
      echo "$container_info $imageid $envs"
    fi
  done
}

function scan-permission() {
  output="${1:-permission.txt}"
  hostname=$(sh -c hostname)
  images=$($DOCKER_IMAGE_LS | awk 'NR!=1 {print $3}')
  echo "hostname | image | permission | file"
  # shellcheck disable=SC2068
  for image in ${images[@]}; do

    if [ "$RUNTIME" = "docker" ]; then
      # shellcheck disable=SC2086
      repo_tags=$($DOCKER_INSPECT --format="{{index .RepoTags 0}}" $image 2>/dev/null)
      result=$($DOCKER_INSPECT -f {{.GraphDriver.Data.UpperDir}} "${image}" | awk -F ":" 'BEGIN{OFS="\n"}{ for(i=1;i<=NF;i++)printf("%s\n",$i)}' |
        xargs -I {} find {} ! -perm 600 -name "*.crt" -o ! -perm 600 -name "*.pem" -o ! -perm 640 -name "*.conf" -o ! -perm 640 "*.properties" 2>/dev/null |
        xargs -I {} ls -l {} | awk -F ' ' '{if (NR>1) {printf("%s %s %s %s %s\n", "'$hostname'", "'$image'", "'$repo_tags'", $1, $9)}}' 2>/dev/null)
      if [ "$result" != "" ]; then
        echo "$result"
        echo "$result" >>$output
      fi
      # shellcheck disable=SC2086
      result=$($DOCKER_INSPECT -f {{.GraphDriver.Data.LowerDir}} "${image}" | awk -F ":" 'BEGIN{OFS="\n"}{ for(i=1;i<=NF;i++)printf("%s\n",$i)}' |
        xargs -I {} find {} ! -perm 600 -name "*.crt" -o ! -perm 600 -name "*.pem" -o ! -perm 640 -name "*.conf" -o ! -perm 640 "*.properties" 2>/dev/null |
        xargs -I {} ls -l {} | awk -F ' ' '{if (NR>1) {printf("%s %s %s %s %s\n", "'$hostname'", "'$image'", "'$repo_tags'", $1, $9)}}' 2>/dev/null)
      if [ "$result" != "" ]; then
        echo "$result"
        echo "$result" >>$output
      fi
    elif [ "$RUNTIME" = "isula" ]; then
      repo_tags=$($DOCKER_INSPECT -f {{.image.repo_tags}} $image | grep -Eo '[a-z\w]+[a-z0-9\w]+[^"]*')
      result=$($DOCKER_INSPECT -f {{.image.Spec.rootfs.diff_ids}} "${image}" |
        grep -Eo '(sha256:[a-f0-9]+)' | awk -F: '{printf("/var/lib/isulad/storage/overlay/%s\n", $2)}' |
        xargs -I {} find {} ! -perm 600 -name "*.crt" -o ! -perm 600 -name "*.pem" -o ! -perm 640 -name "*.conf" ! -perm 640 "*.properties" 2>/dev/null |
        xargs -I {} ls -l {} | awk -F ' ' '{if (NR>1) {printf("%s %s %s %s %s\n", "'$hostname'", "'$image'", "'$repo_tags'", $1, $9)}}' 2>/dev/null)
      if [ "$result" != "" ]; then
        echo "$result"
        echo "$result" >>$output
      fi
    fi
  done
  echo "output: $output"
}

function scan-token() {
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
}

function scan-openssl() {
  hostname=$(sh -c hostname)
  echo " hostname | image | tag | container | file"
  containers=$($DOCKER_PS | awk 'NR!=1 {print $1}')
  # shellcheck disable=SC2068
  for container in ${containers[@]}; do
    # shellcheck disable=SC2046
    # shellcheck disable=SC1066
    container_info=$($DOCKER_PS --format="{{.ID}}  {{.Image}}  {{.Names}}" | grep "$container")
    image=$($DOCKER_PS | grep "$container" | awk '{print $2}')
    if [ "$RUNTIME" = "docker" ]; then
      repo_tags=$($DOCKER_INSPECT --format="{{index .RepoTags 0}}" $image 2>/dev/null)
      mounts=$($DOCKER_INSPECT --format='{{range .Mounts}}{{printf "%s\n" .Source}}{{end}}' "$container")
    elif [ "$RUNTIME" = "isula" ]; then
      repo_tags=$($DOCKER_INSPECT --format="{{.image.repo_tags}}" $image | grep -Eo '[a-z\w]+[a-z0-9\w]+[^"]*')
      mounts=$($DOCKER_INSPECT --format="{{.Mounts}}" $container | grep -Eo '("Source":[^,]*)' | awk -F: '{print $2}' | sed 's/ //g')
    else
      repo_tags=""
      mounts=""
    fi

    # shellcheck disable=SC2034
    for mount_dir in ${mounts[@]}; do
      if [[ $mount_dir = "/proc" ]] || [[ $mount_dir = "/sys" ]] || [[ $mount_dir = "/" ]]; then
        continue
      fi
      mount_files=$(find "$mount_dir" -type f -name "*.key")
      for mount_file in ${mount_files[@]}; do
        #        is_encrypted=$(grep -c "BEGIN ENCRYPTED PRIVATE KEY" "$mount_file")
        is_private_key=$(grep -c "PRIVATE KEY" "$mount_file")
        is_encrypted=$(grep -c "ENCRYPTED" "$mount_file")
        if [[ $is_private_key = '2' ]]; then
          if [[ "$is_encrypted" = '0' ]]; then
            echo "$hostname $image $repo_tags $container $mount_file"
          fi
        fi
      done
    done

    upper_files=$($DOCKER_INSPECT -f {{.GraphDriver.Data.UpperDir}} "$container" | sed 's/:/\n/g' | xargs -I {} find {} -type f -name "*.key" 2>/dev/null)
    if [[ $upper_files != "" ]]; then
      for upper_file in ${upper_files[@]}; do
        is_private_key=$(grep -c "PRIVATE KEY" "$mount_file")
        is_encrypted=$(grep -c "ENCRYPTED" "$mount_file")
        if [[ $is_private_key = '2' ]]; then
          if [[ "$is_encrypted" = '0' ]]; then
            echo "$hostname $image $repo_tags $container $upper_file"
          fi
        fi
      done
    fi
    lower_files=$($DOCKER_INSPECT -f {{.GraphDriver.Data.LowerDir}} "$container" | sed 's/:/\n/g' | xargs -I {} find {} -type f -name "*.key" 2>/dev/null)
    if [[ $lower_files != "" ]]; then
      for lower_file in ${lower_files[@]}; do
        is_private_key=$(grep -c "PRIVATE KEY" "$mount_file")
        is_encrypted=$(grep -c "ENCRYPTED" "$mount_file")
        if [[ $is_private_key = '2' ]]; then
          if [[ "$is_encrypted" = '0' ]]; then
            echo "$hostname $image $repo_tags $container $lower_file"
          fi
        fi
      done
    fi

  done
}

function scan-noowner() {
  dir=${1:-/}
  # shellcheck disable=SC2038
  find $dir -xdev \( -nouser -o -nogroup \) \( ! -path "/proc" -o ! -path "/sys" \) -type f -print | xargs -I {} ls -l {}
}

function utils {
  if [ ${debug:-false} = true ]; then
    set -x
  fi

  CMD=$1
  if [ "$CMD" = "privileged" ]; then
    scan-privileged
  elif [ "$CMD" = "root" ]; then
    scan-root
  elif [ "$CMD" = "tools" ]; then
    scan-tools $2
  elif [ "$CMD" = "env" ]; then
    scan-env
  elif [ "$CMD" = "permission" ]; then
    scan-permission $2
  elif [ "$CMD" = "token" ]; then
    scan-token
  elif [ "$CMD" = "openssl" ]; then
    scan-openssl
  elif [ "$CMD" = "noowner" ]; then
    scan-noowner $2
  fi
}

utils $1 $2
