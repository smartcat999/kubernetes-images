#!/usr/bin/env bash

# 1. 导出k8s所有节点镜像
# ./k8s-exporter.sh images/image/img/i

function message() {
    # echo -e "\033[字背景颜色；文字颜色m字符串\033[0m"
    echo -e "\033[32m$1\033[0m"
}

function warn() {
    echo -e "\033[34m$1\033[0m"
}

function export-node-images-list() {
  images=$(kubectl get nodes $1 -o jsonpath="{ .status.images[*].names }" \
  | sed 's/ /\n/g' | sed 's/\[//g' | sed 's/\]//g' | grep -v '<nil>')
  # shellcheck disable=SC2068
  for image in ${images[@]}; do
    hash_tag=$(echo $image | awk -F, '{print $1}')
    tag=$(echo $image | awk -F, '{print $2}')
    if [ "$tag" = "" ] || [ "$tag" = "<nil>" ]; then
      image_tag=$hash_tag
    else
      image_tag=$tag
    fi
    # shellcheck disable=SC2001
    image_tag=$(echo "$image_tag" | sed 's/"//g')
    echo "$image_tag"
  done
}

function export-images-tar() {
  dir=$(dirname $0)
  package_name="qkcp-v4-offline-images-linux-arm64.tar.gz"
  package_dir="$dir/package"
  manifests="$package_dir/manifests.txt"
  message "manifests: $manifests"
  images_dir="$package_dir/images"
  all_node_images=""

  cat /dev/null >$manifests

  if [ ! -d "$images_dir" ]; then
    mkdir -p $images_dir
  fi

  nodes=$(kubectl get nodes | awk '{if (NR>1) print $1 }')
  # shellcheck disable=SC2068
  for node in ${nodes[@]}; do
    node_images=$(export-node-images-list $node)
    echo "$node_images" >>$manifests
  done
  all_node_images=$(cat "$manifests" | sort | uniq)
  echo "$all_node_images" >>$manifests
  # shellcheck disable=SC2068
  for node_image in ${all_node_images[@]}; do
    image_tar="$images_dir/$(echo "$node_image" | sed 's/\//-/g' | sed 's/:/-/g').tar"
    message "save: $image_tar"
    docker pull $node_image && docker save $node_image -o $image_tar && docker system prune -a -f
#    docker pull $node_image && docker save $node_image -o $image_tar && docker rmi $node_image &
  done
#  wait
  if [ "$all_node_images" != "" ]; then
    # package image.tar
    tar -zcvf $package_name $package_dir
    # shellcheck disable=SC2181
    if [ $? -eq 0 ]; then
      message "package success !!!"
      message "save package to $dir/$package_name"
    fi
  fi

  # clean useless file
  warn "clean $images_dir"
  rm -rf $images_dir
}

case "$1" in
images | image | img | i)
  export-images-tar
  ;;
*)
  # shellcheck disable=SC2028
  echo "\n unsupported command \n"
  ;;
esac
