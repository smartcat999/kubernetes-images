#!/usr/bin/env bash

# 同步 dockerhub ks 镜像到 harbor 仓库
# 1. ./sync-ks-image.sh sync-docker-harbor

# 同步 aliyun ks 镜像到 harbor 仓库
# 2. ./sync-ks-image.sh  sync-aliyuncs-harbor(

# 下载 harbor 仓库镜像保存为 .tar.gz 文件
# 3. ./sync-ks-image.sh save-images

# 加载 .tar.gz 文件到镜像
# 4. ./sync-ks-image.sh load-images

# 上传镜像文件到测试环境并更新deployment
# 修改 ks-image.tmp 中对应的镜像地址，执行以下命令更新
# 5. ./sync-ks-image.sh deploy

# 导出k8s集群镜像
# 6. ./sync-ks-image.sh export

# 同步harbor镜像
# 7. ./sync-ks-image.sh harbor

if [[ ${debug:-flase} = "true" ]]; then
  set -x
fi

CMD=$1
DEFAULT_IMAGE=(
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
# shellcheck disable=SC2128
IMAGE_UPDATE=${IMAGE_UPDATE:-"$DEFAULT_IMAGE"}

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
    file="$(echo $image | sed 's/:/_/g').tar.gz"
    docker pull "$repo/$image" && docker save "$repo/$image" -o "${file}"
  done
}

# save-tag-image registry.cn-beijing.aliyuncs.com/kse/ks-apiserver:release-3.3-isdp \
#  dockerhub.kubekey.local/huawei/ks-apiserver:release-3.3-isdp \
#  ks-apiserver-release-3.3-isdp.tar
function save-tag-image() {
  docker pull $1 &&
    docker tag $1 $2 &&
    docker save $2 -o $3
}

function load-images() {
  # shellcheck disable=SC2128
  repo=${repo:-dockerhub.kubekey.local/huawei}
  # shellcheck disable=SC2068
  for image in ${IMAGE_UPDATE[@]}; do
    # shellcheck disable=SC2001
    filename="$(echo $image | sed 's/:/_/g').tar.gz"
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

function deploy-ks-image() {
  dir=$(dirname $0)
  echo "dir: $dir"
  file=$dir/ks-image.tmp
  if [[ -f "$file" ]]; then
    # shellcheck disable=SC2046
    echo "input: $file"
    # shellcheck disable=SC2005
    echo "$(cat $file)"
  else
    cat >"$file" <<EOF
API_IMAGE=
CONTROLLER_IMAGE=
CONSOLE_IMAGE=
EOF
    echo "please write image_tag in ${file}
API_IMAGE=*****
CONTROLLER_IMAGE=*****
CONSOLE_IMAGE=*****
"
    exit
  fi
  # shellcheck disable=SC2002
  API_IMAGE=$(cat "$file" | grep "API_IMAGE=" | cut -d= -f2)
  if [[ "$API_IMAGE" != "" ]]; then
    TARGET_API_IMAGE=dockerhub.kubekey.local/huawei/ks-apiserver:release-3.3-isdp
    TARGET_API_IMAGE_FILE=ks-apiserver-release-3.3-isdp.tar
    save-tag-image $API_IMAGE $TARGET_API_IMAGE $TARGET_API_IMAGE_FILE
  fi

  # shellcheck disable=SC2002
  CONTROLLER_IMAGE=$(cat "$file" | grep "CONTROLLER_IMAGE=" | cut -d= -f2)
  if [[ "$CONTROLLER_IMAGE" != "" ]]; then
    TARGET_CONTROLLER_IMAGE=dockerhub.kubekey.local/huawei/ks-controller-manager:release-3.3-isdp
    TARGET_CONTROLLER_IMAGE_FILE=ks-controller-manager-release-3.3-isdp.tar
    save-tag-image $CONTROLLER_IMAGE $TARGET_CONTROLLER_IMAGE $TARGET_CONTROLLER_IMAGE_FILE
  fi

  CONSOLE_IMAGE=$(cat "$file" | grep "CONSOLE_IMAGE=" | cut -d= -f2)
  if [[ "$CONSOLE_IMAGE" != "" ]]; then
    TARGET_CONSOLE_IMAGE=dockerhub.kubekey.local/huawei/ks-console:kse-release-3.3-isdp
    TARGET_CONSOLE_IMAGE_FILE=ks-console-kse-release-3.3-isdp.tar
    save-tag-image $CONSOLE_IMAGE $TARGET_CONSOLE_IMAGE $TARGET_CONSOLE_IMAGE_FILE
  fi

  # upload ks image
  scp -P 2222 $TARGET_CONSOLE_IMAGE_FILE $TARGET_API_IMAGE_FILE $TARGET_CONTROLLER_IMAGE_FILE \
    service@localhost:/home/service/

  NODE=192.168.200.3
  ssh service@localhost -p 2222 \
    "scp /home/service/$TARGET_CONSOLE_IMAGE_FILE /home/service/$TARGET_API_IMAGE_FILE /home/service/$TARGET_CONTROLLER_IMAGE_FILE root@$NODE:/root/"
  ssh service@localhost -p 2222 \
    "ssh root@$NODE 'docker load -i /root/$TARGET_CONSOLE_IMAGE_FILE && \
  docker push $TARGET_CONSOLE_IMAGE && \
  kubectl -n kubesphere-system set image deploy ks-console ks-console=$TARGET_CONSOLE_IMAGE && \
  kubectl -n kubesphere-system rollout restart deploy ks-console
  docker load -i /root/$TARGET_API_IMAGE_FILE && \
  docker push $TARGET_API_IMAGE && \
  kubectl -n kubesphere-system set image deploy ks-apiserver ks-apiserver=$TARGET_API_IMAGE && \
  kubectl -n kubesphere-system rollout restart deploy ks-apiserver \
  docker load -i /root/$TARGET_CONTROLLER_IMAGE_FILE && \
  docker push $TARGET_CONTROLLER_IMAGE &&
  kubectl -n kubesphere-system set image deploy ks-controller-manager ks-controller-manager=$TARGET_CONTROLLER_IMAGE && \
  kubectl -n kubesphere-system rollout restart deploy ks-controller-manager'"
}

function export-k8s-images() {
  dir=$(dirname $0)
  script=k8s-exporter.sh
  package=qkcp-v4-offline-images-linux-arm64.tar.gz
  scp -P 2222 $script service@localhost:/home/service
  NODE=192.168.200.3
  # shellcheck disable=SC2087
  ssh service@localhost -p 2222 << eeooff
scp /home/service/$script root@$NODE:/var/lib/docker
ssh root@$NODE 'chmod +x /var/lib/docker/$script && cd /var/lib/docker/ && ./$script images'
scp root@$NODE:/var/lib/docker/$package /home/service
scp -P 2222 service@localhost:/home/service/$package /root/wp
eeooff
#    ssh service@localhost -p 2222 \
#      "rm /home/service/$package && ssh root@$NODE 'rm $package'"
}

function export-harbor-images() {
  images=(
    osixia/openldap:1.3.0
    kubesphere/openpitrix-jobs:v3.2.2
    kubesphere/devops-apiserver:v3.3.2
    kubesphere/devops-tools:v3.3.2
    kubesphere/devops-controller:v3.3.2
    kubesphere/builder-go:v3.2.0
    kubesphere/builder-base:v3.2.2
    kubesphere/builder-nodejs:v3.2.0
    kubesphere/builder-maven:v3.2.0
    kubesphere/builder-python:v3.2.0
    jenkins/inbound-agent:4.10-2
  )
  # shellcheck disable=SC2068
  for image in ${images[@]}; do
    sudo docker pull $image && sudo docker tag $image harbor.wuxs.vip/$image && sudo docker push harbor.wuxs.vip/$image
  done
  sudo docker pull jenkins/jenkins:2.332.3 && sudo docker tag jenkins/jenkins:2.332.3 harbor.wuxs.vip/kubesphere/ks-jenkins:v3.3.0-2.319.1 && sudo docker push harbor.wuxs.vip/kubesphere/ks-jenkins:v3.3.0-2.319.1
}

if [ $CMD = "docker" ]; then
  sync-docker-harbor
elif [ $CMD = "ali" ]; then
  sync-aliyuncs-harbor
elif [ "$CMD" = "save_images" ]; then
  save-images
elif [ "$CMD" = "load_images" ]; then
  load-images
elif [ "$CMD" = "deploy" ]; then
  deploy-ks-image
elif [ "$CMD" = "export" ]; then
  export-k8s-images
elif [ "$CMD" = "harbor" ]; then
  export-harbor-images
fi
