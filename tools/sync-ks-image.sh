#!/usr/bin/env bash

# 同步 dockerhub ks 镜像到 harbor 仓库
# 1. ./sync-ks-image.sh sync-docker-harbor

# 同步 aliyun ks 镜像到 harbor 仓库
# 2. ./sync-ks-image.sh  sync-aliyuncs-harbor(

# 下载 harbor 仓库镜像保存为 .tar.gz 文件
# 3. ./sync-ks-image.sh save-images

# 加载 .tar.gz 文件到镜像
# 4. ./sync-ks-image.sh load-images

if [[ ${debug:-flase} = "true" ]]; then
  set -x
fi

CMD=$1

IMAGE_UPDATE=(
  ks-apiserver:v3.3.2-HW
  ks-controller-manager:v3.3.2-HW
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

function sync-docker-harbor() {
  SOURCE_IMAGE_HUB=2030047311
  TARGET_IMAGE_HUB=dockerhub.kubekey.local/huawei

  IMAGE_TAG=v3.3.0-20230220

  API_IMAGE=ks-apiserver:${IMAGE_TAG}
  CONTROLLER_IMAGE=ks-controller-manager:${IMAGE_TAG}

  IMAGE_ARR=(${API_IMAGE} ${CONTROLLER_IMAGE})

  # shellcheck disable=SC2068
  for i in ${IMAGE_ARR[@]}; do
    docker pull ${SOURCE_IMAGE_HUB}/"$i" --platform linux/arm64 &&
      docker tag ${SOURCE_IMAGE_HUB}/"$i" ${TARGET_IMAGE_HUB}/"$i" &&
      docker push ${TARGET_IMAGE_HUB}/"$i"
  done
}

function sync-aliyuncs-harbor() {
  file=ks-image.tmp
  if [[ -f "$file" ]]; then
    # shellcheck disable=SC2046
    echo $(cat "$file")
  else
    cat >"$file" <<EOF
API_IMAGE_TAG=
CONTROLLER_IMAGE_TAG=
EOF
    echo "please write image_tag in ${file}
registry.cn-beijing.aliyuncs.com/kse/API_IMAGE_TAG
"
    exit
  fi
  # shellcheck disable=SC2002
  API_IMAGE_TAG=$(cat "$file" | grep "API_IMAGE_TAG=" | cut -d= -f2)
  # shellcheck disable=SC2002
  CONTROLLER_IMAGE_TAG=$(cat "$file" | grep "CONTROLLER_IMAGE_TAG=" | cut -d= -f2)
  SOURCE_IMAGE_HUB=registry.cn-beijing.aliyuncs.com/kse
  SOURCE_API_IMAGE=${SOURCE_IMAGE_HUB}/${API_IMAGE_TAG}
  SOURCE_CONTROLLER_IMAGE=${SOURCE_IMAGE_HUB}/${CONTROLLER_IMAGE_TAG}

  TARGET_IMAGE_HUB=dockerhub.kubekey.local/huawei
  TARGET_API_IMAGE=${TARGET_IMAGE_HUB}/ks-apiserver:v3.3.2-HW
  TARGET_CONTROLLER_IMAGE=${TARGET_IMAGE_HUB}/ks-controller-manager:v3.3.2-HW

  # shellcheck disable=SC2086
  docker pull $SOURCE_API_IMAGE &&
    docker tag "$SOURCE_API_IMAGE" $TARGET_API_IMAGE &&
    docker push $TARGET_API_IMAGE

  docker pull "$SOURCE_CONTROLLER_IMAGE" &&
    docker tag "$SOURCE_CONTROLLER_IMAGE" $TARGET_CONTROLLER_IMAGE &&
    docker push $TARGET_CONTROLLER_IMAGE

}

function save-images() {
  # shellcheck disable=SC2128
  repo=${repo:-dockerhub.kubekey.local/huawei}
  # shellcheck disable=SC2068
  for image in ${IMAGE_UPDATE[@]}; do
    file="$(echo image | sed 's/:/_/g').tar.gz"
    docker pull "$repo/$image" && docker save "$repo/$image" -o "${file}"
  done
}

function load-images() {
  # shellcheck disable=SC2128
  repo=${repo:-dockerhub.kubekey.local/huawei}
  # shellcheck disable=SC2068
  for image in ${IMAGE_UPDATE[@]}; do
    # shellcheck disable=SC2001
    filename="$(echo image | sed 's/:/_/g').tar.gz"
    if [ -f "$filename" ]; then
      image_tag=$(docker load -i "$filename" | awk '{print $3}')
      # shellcheck disable=SC2154
      docker tag "$image_tag" "$repo/$image"
      docker push "$repo/$image"
    else
      echo "$filename not found"
    fi
  done
}

if [[ $CMD = "docker" ]]; then
  sync-docker-harbor
elif [[ $CMD = "ali" ]]; then
  sync-aliyuncs-harbor
elif [ "$CMD" = "save_images" ]; then
  save-images
elif [ "$CMD" = "load_images" ]; then
  load-images
fi
