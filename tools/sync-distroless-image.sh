#!/bin/bash

if [[ ${debug:-flase} = "true" ]]; then
  set -x
fi

CMD=$1

REPO=${REPO:-2030047311}
DEBIAN_VERSION=debian12
ARCH=(
  amd64
  arm64
)
NODEJS_VERSIONS=(
  nodejs20
)
IMAGE_TAG=(
  nonroot
  nonroot-debug
)

function build-nodejs() {
  # shellcheck disable=SC2068
  for tag in ${IMAGE_TAG[@]}; do
    # shellcheck disable=SC2068
    for version in ${NODEJS_VERSIONS[@]}; do
      if [[ $tag = "nonroot" ]]; then
        bazel build nodejs:${version}_nonroot_${DEBIAN_VERSION}
      else
        bazel build nodejs:${version}_debug_nonroot_${DEBIAN_VERSION}
      fi
    done
  done

  # shellcheck disable=SC2068
  for tag in ${IMAGE_TAG[@]}; do
    # shellcheck disable=SC2068
    # shellcheck disable=SC2034
    for version in ${NODEJS_VERSIONS[@]}; do
      manifest=${REPO}/${version}-${DEBIAN_VERSION}:${tag}
      for arch in ${ARCH[@]}; do
        # shellcheck disable=SC2128

        image=${REPO}/${version}-${DEBIAN_VERSION}:${tag}-${arch}
        if [[ $tag = "nonroot" ]]; then
          oci_dir=oci:bazel-bin/nodejs/${version}_nonroot_${arch}_${DEBIAN_VERSION}
        else
          oci_dir=oci:bazel-bin/nodejs/${version}_debug_nonroot_${arch}_${DEBIAN_VERSION}
        fi
        skopeo copy $oci_dir docker-daemon:$image
        docker push $image
        docker manifest create $manifest -a $image
      done
      docker manifest push $manifest
    done
  done
}

function build-base() {
  # shellcheck disable=SC2068
  for tag in ${IMAGE_TAG[@]}; do
    if [[ $tag = "nonroot" ]]; then
      bazel build base:base_nonroot_${DEBIAN_VERSION}
    else
      bazel build base:debug_nonroot_${DEBIAN_VERSION}
    fi
  done

  # shellcheck disable=SC2068
  for tag in ${IMAGE_TAG[@]}; do
    # shellcheck disable=SC2068
    # shellcheck disable=SC2034
    manifest=${REPO}/base-${DEBIAN_VERSION}:${tag}
    for arch in ${ARCH[@]}; do
      # shellcheck disable=SC2128

      image=${REPO}/base-${DEBIAN_VERSION}:${tag}-${arch}
      if [[ $tag = "nonroot" ]]; then
        oci_dir=oci:bazel-bin/base/base_nonroot_${arch}_${DEBIAN_VERSION}
      else
        oci_dir=oci:bazel-bin/base/debug_nonroot_${arch}_${DEBIAN_VERSION}
      fi
      skopeo copy $oci_dir docker-daemon:$image
      docker push $image
      docker manifest create $manifest -a $image
    done
    docker manifest push $manifest
  done
}

if [[ $CMD = "nodejs" ]]; then
  build-nodejs
elif [[ $CMD = "base" ]]; then
  build-base
fi