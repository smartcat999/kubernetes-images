#!/bin/bash

# 获取用户信息
users=$(cat /etc/passwd | cut -d: -f1 | sort)

# 输出表头
printf '%-20s %-20s %-20s\n' "Account" "Group" "Home"
printf '%.0s-' {1..60}
echo

# 遍历用户信息并输出账号、用户组、家目录
for user in $users; do
  group=$(id -gn $user)
  home=$(eval echo ~$user)

  # 输出用户信息到表格
  printf '%-20s %-20s %-20s\n' "$user" "$group" "$home"
done
