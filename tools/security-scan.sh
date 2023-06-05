#!/bin/bash

# cat >> /etc/cron.d/security-scan <<EOF
# * * * * * root /bin/bash /opt/tasks/security-scan.sh
# EOF
# 或 注意用户名区别
# crontab -e
# 添加 */10 * * * * /bin/bash /opt/tasks/security-scan.sh

function check-modify-permission() {
  dir=$1
  file=$2
  permission=$3
  # shellcheck disable=SC2038
  find $dir -type f -name $file ! -perm $permission | xargs chmod $permission 2>/dev/null
}

function modify-permission() {
  dir=$1
  file=$2
  permission=$3
  # shellcheck disable=SC2038
  find $dir -type f -name $file | xargs chmod $permission 2>/dev/null
}

function modify-no-owner-file() {
  dir=$1
  # shellcheck disable=SC2038
  files=$(find $1 -xdev \( -nouser -o -nogroup \) \( ! -path "/proc" -o ! -path "/sys" \) -type f -print)
  # shellcheck disable=SC2068
  for file in ${files[@]}; do
    info=$(echo $file | xargs ls -l)
    uid=$(echo $info | awk '{print $3}')
    gid=$(echo $info | awk '{print $4}')
    target=$(echo $info | awk '{print $9}')
    echo "uid: $uid,gid: $gid,file: $target"
    # shellcheck disable=SC2046
    if [ "$(getent passwd $uid)" = "" ]; then
      useradd -u $uid user$uid
    fi
    # shellcheck disable=SC2046
    if [ "$(getent group $gid)" = "" ]; then
      groupadd -g $gid group$gid
    fi
  done
}

check-modify-permission "/var/lib/docker/overlay2" "*.conf" 640
check-modify-permission "/var/lib/docker/overlay2" "*.crt" 600
check-modify-permission "/var/lib/docker/overlay2" "*.pem" 600
modify-permission "/var/lib/docker/overlay2" "*.log" -x
modify-no-owner-file "/"
