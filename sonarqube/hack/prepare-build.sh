#!/usr/bin/env bash

VERSION=${VERSION:-v8}

if [ "$VERSION" == "v8" ]; then
  if [ ! -d "./tmp" ]; then
    mkdir ./tmp
  fi
  plugin=./tmp/sonar-pdfreport-plugin-4.0.0.jar
  if [ ! -f "$plugin" ]; then
    # Download sonar-pdfreport-plugin
    curl -SsL https://gitee.com/zzulj/sonar-pdf-plugin/releases/download/v4.0.0/sonar-pdfreport-plugin-4.0.0.jar -o $plugin.tmp
    mv $plugin.tmp $plugin
  fi

fi