#!/bin/bash

# 用户名,初始密码,用户用途,Shell类型,家目录,用户状态,登录方式,备注
function export-system-account() {
  file=account.csv
  # shellcheck disable=SC2028
  echo "用户名,初始密码,用户用途,Shell类型,家目录,用户状态,登录方式,备注" >$file
  # shellcheck disable=SC2162
  while read line; do
    username=$(echo $line | awk -F: '{print $1}')
    effect=$(echo $line | awk -F: '{print $5}')
    shell="Bourne shell(sh)"
    home_dir=$(echo $line | awk -F: '{print $6}')

    passwd_status=$(cat /etc/shadow | grep $username | awk -F: '{print $2}')
    # shellcheck disable=SC1079
    if [ "$passwd_status" = "*" ] || [ "$passwd_status" = "!" ] || [ "$passwd_status" = "!!" ]; then
      status="锁定"
      login="禁止登录"
      passwd="NA"
    else
      status="启用"
      login="NA"
      passwd="***"
    fi
    remark=""
    # shellcheck disable=SC2028
    echo "$username,$passwd,$effect,$shell,$home_dir,$status,$login,$remark" >>$file
  done </etc/passwd
}

function export-container-account() {
  file=container_account.csv
  echo "用户名,初始密码,用户用途,Shell类型,家目录,用户状态,登录方式,备注" >$file
  tmp_user_file=./tmp_user.txt
  tmp_shadow_file=./tmp_shadow.txt
  # shellcheck disable=SC2038
  find /var/lib/docker/isulad/storage/overlay/ -name "passwd" | grep /etc/passwd | xargs -I {} cat {} | sort | uniq >$tmp_user_file
  find /var/lib/docker/isulad/storage/overlay/ -name "shadow" | grep /etc/shadow | xargs -I {} cat {} | sort | uniq >$tmp_shadow_file.tmp
  cat /etc/shadow >>$tmp_shadow_file.tmp
  cat $tmp_shadow_file.tmp | sort | uniq >$tmp_shadow_file
  rm $tmp_shadow_file.tmp

  while read line; do
    username=$(echo $line | awk -F: '{print $1}')
    effect=$(echo $line | awk -F: '{print $5}')
    shell="Bourne shell(sh)"
    home_dir=$(echo $line | awk -F: '{print $6}')

    passwd_status=$(cat $tmp_shadow_file | grep $username | head -n 1 | awk -F: '{print $2}')
    # shellcheck disable=SC1079
    if [ "$passwd_status" = "*" ] || [ "$passwd_status" = "!" ] || [ "$passwd_status" = "!!" ]; then
      status="锁定"
      login="禁止登录"
      passwd="NA"
    else
      status="启用"
      login="NA"
      passwd="***"
    fi
    remark=""
    # shellcheck disable=SC2028
    echo "$username,$passwd,$effect,$shell,$home_dir,$status,$login,$remark" >>$file
  done <$tmp_user_file
  rm $tmp_user_file $tmp_shadow_file
}

export-system-account
export-container-account
