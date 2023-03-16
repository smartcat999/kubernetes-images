#!/bin/bash

# shellcheck disable=SC2039
PLATFORMS=('linux/arm64' 'linux/amd64')
# shellcheck disable=SC2034
echo "input image：$1";
REPO=${2:-2030047311}
echo "repo: $REPO";
if [ "$1" = "" ]
then
  echo "please input image url"
  exit 1
fi

# parse repo/image:tag => image:tag
# shellcheck disable=SC2206
IMAGE=$(echo "$1" | awk -F'/' '{for (i=1; i<=NF; i++) if (i==NF) print $i}')

# shellcheck disable=SC2128
# shellcheck disable=SC2068
# shellcheck disable=SC2039
for element in ${PLATFORMS[@]}
do
  docker pull "$1" --platform "$element"
  # shellcheck disable=SC2154
  NEW_IMAGE=$REPO/$IMAGE-$(echo "$element" | awk -F'/' '{for (i=1; i<=NF; i++) if (i==NF) print $i}')
  docker tag "$1" "$NEW_IMAGE"
  docker push "$NEW_IMAGE"
  docker manifest create "$REPO/$IMAGE" -a "$NEW_IMAGE"
done

docker manifest push "$REPO/$IMAGE"

