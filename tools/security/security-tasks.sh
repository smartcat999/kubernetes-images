#!/bin/bash

#cat >> /etc/cron.d/security-scan <<EOF
#*/1 * * * * root /bin/bash /opt/tasks/security-tasks.sh
#EOF
# 或 注意用户名区别
# crontab -e
# 添加 */1 * * * * /bin/bash /opt/tasks/security-tasks.sh
# crontab 中命令需要写完整路径，比如：kubectl > /usr/local/bin/kubectl;

if [ ${debug:-false} = true ]; then
  set -x
fi

function watch-server-dns() {
  dns=$1
  ns=$2
  svc=$3
  target=/etc/hosts
  if [[ "$ns" = "" ]]; then
    echo "Error: empty ns"
    exit
  fi
  cluster_ip=$(/usr/local/bin/kubectl get svc $svc -n $ns | grep $svc | awk '{print $3}')
  if [[ "$cluster_ip" = "" ]]; then
    #echo "$svc not found"
    exit 1
  fi
  dns_rule="$cluster_ip $dns"
  # shellcheck disable=SC2143
  if [[ "$(grep $dns $target)" = "" ]]; then
    echo "$dns_rule" >> $target
    echo "add $dns_rule"
  else
    # shellcheck disable=SC2005
    # shellcheck disable=SC2094
    cp "${target}" "${target}_bk"
    expr="s/[0-9]*.[0-9]*.[0-9]*.[0-9]* $dns/$dns_rule/"
#    echo "$expr"
    sed -i "${expr}" "${target}"
    echo "update $dns_rule"
  fi
}

watch-server-dns ks-apiserver.kubesphere-system.svc kubesphere-system ks-apiserver
