#!/bin/bash

version=$(curl -s "https://api.github.com/repos/Dreamacro/clash/releases/latest" | grep '"tag_name":' | cut -d'"' -f4)

function download-clash() {
  os=$1
  arch=$2
  ver=$3
  file=clash-$os-$arch-$ver
  curl -SsOL https://github.com/Dreamacro/clash/releases/download/$ver/$file.gz
  gzip -df $file.gz
  chmod +x $file
  mv $file clash-$os-$arch
}

download-clash linux amd64 $version
download-clash linux arm64 $version
download-clash linux armv7 $version