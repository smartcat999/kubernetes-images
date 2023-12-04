#!/bin/bash

# 1. 检查privileged特权容器
# ./scan-remote.sh privileged

# 2. 检查root用户容器
# ./scan-remote root

# 3. 检查包含调试/嗅探工具的镜像
# ./scan-remote tools

# 4. 检查环境变量中含有敏感信息的容器
# ./scan-remote env

# 5. 检查配置文件/证书文件权限不是600的镜像
# ./scan-remote permission

# 6. 检查挂载k8s token的容器
# ./scan-remote token

# 7. 检查容器本身的证书私钥 以及 挂载的私钥是否加密
# ./scan-remote openssl

# 8. 检查系统的无属组文件
# 不传path默认扫描 / 目录下的文件，不扫描 /proc 和 /sys
# ./scan-remote noowner ${path}

# 9. 检查系统的账号
# ./scan-remote account


if [ ${debug:-false} = true ]; then
  set -x
fi

target=${target:-172.31.50.147 172.31.50.148 172.31.50.149}

hostname=$(sh -c hostname)
node_ip=$(kubectl get node -o wide | grep "$hostname" | awk '{print $6}')
echo "node_ip: $node_ip"
if [ "$node_ip" = "" ]; then
  return
fi

# shellcheck disable=SC2068
for elem in ${target[@]}; do
  if [ "$elem" = "$node_ip" ]; then
    continue
  fi
  scp -q image-scan.sh security-account.sh "root@$elem:/root/"
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

function dump_privileged_containers {
  ./image-scan.sh privileged
  batch_run "/root/image-scan.sh privileged"
}

function dump_root_containers {
  ./image-scan.sh root
  batch_run "/root/image-scan.sh root"
}

function dump_tools_containers {
  ./image-scan.sh tools
  batch_run "/root/image-scan.sh tools"
}

function dump_envs_containers {
  ./image-scan.sh env
  batch_run "/root/image-scan.sh env"
}

function dump_permission_file_images {
  ./image-scan.sh permission
  batch_run "/root/image-scan.sh permission"
}

function dump_api_access_token_containers {
  ./image-scan.sh token
  batch_run "/root/image-scan.sh token"
}

function dump_openssl_containers {
  ./image-scan.sh openssl
  batch_run "/root/image-scan.sh openssl"
}

function dump_noowner_containers {
  ./image-scan.sh noowner
  batch_run "/root/image-scan.sh noowner"
}

function clean_image_unused() {
  ./image-scan.sh clean
  batch_run "/root/image-scan.sh clean"
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
elif [ "$CMD" = "noowner" ]; then
  dump_noowner_containers
elif [ "$CMD" = "account" ]; then
  dump_system_account
elif [ "$CMD" = "clean" ]; then
  clean_image_unused
fi
