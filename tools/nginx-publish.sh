#!/bin/bash

DIST_DIR=/opt/frontend/
SERVER_NAME=local.web.com
NGINX_CONG_DIR=/etc/nginx/conf.d/
NGINX_CONF_FRONTEND=frontend.conf

function log_info() {
  echo -e "\e[1;32m$1\e[0m"
}

function install_nginx_ubuntu() {
  apt update -y
  apt install nginx -y
  systemctl status nginx
}

function install_nginx_centos() {
  yum -y update
  yum install -y nginx
  systemctl status nginx
}

function generator_nginx_conf() {
  cat >frontend.conf <<EOF
server {
    listen       80;
    server_name  $SERVER_NAME;

    root $DIST_DIR;

    location / {
        try_files \$uri \$uri/ /index.html;
    }
    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   html;
    }
}
EOF
  echo "> generate config in $PWD/$NGINX_CONF_FRONTEND"
  mv $NGINX_CONF_FRONTEND $NGINX_CONG_DIR
  echo "> mv $NGINX_CONF_FRONTEND to $NGINX_CONG_DIR"
}

function reload_nginx() {
  nginx -t
  nginx -s reload
}

# shellcheck disable=SC2002
os=$(cat /etc/os-release | grep -e ^NAME= | cut -d = -f2)
if [[ $os = '"Ubuntu"' ]]; then
  log_info "System: Ubuntu"

  log_info "1. start install nginx..."
  install_nginx_ubuntu
  echo "> install nginx completed!"
elif
  [[ $os = '"Centos"' ]]
then
  log_info "System: Centos"
  log_info "1. start install nginx..."
  install_nginx_centos
  echo "> install nginx completed!"
fi

log_info "2. start generate nginx conf..."
generator_nginx_conf
echo "> generate nginx conf completed!"

log_info "3. reload nginx config..."
reload_nginx
echo "> reload nginx config completed!"
echo "Please use command below access the page: >>"
log_info "\"curl -H 'Host: $SERVER_NAME' http://127.0.0.1:80\""
