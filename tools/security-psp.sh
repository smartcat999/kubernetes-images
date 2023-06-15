#!/bin/bash

# [debug=true/false] security-psp.sh [create/delete/test-sa/test-psp/tpl]
# 1. 创建psp
# ./security-psp.sh create

# 2. 删除psp
# ./security-psp.sh delete

# 3. 检查sa访问psp的权限
# ./security-psp.sh test-sa

# 4. 检查namespace(默认default)下psp生效的情况
# ./security-psp.sh test-psp [namespace]

# 5. 根据集群namespaces生成特权psp的clusterRoleBinding
# ./security-psp.sh tpl


if [ ${debug:-false} = true ]; then
  set -x
fi

function message() {
  # echo -e "\033[字背景颜色；文字颜色m字符串\033[0m"
  echo -e "\033[32m$1\033[0m"
}

function error() {
  echo -e "\033[31m$1\033[0m"
}

KUBECTL=${KUBECTL:-/usr/local/bin/kubectl}

function privileged-template() {
  psp_file="psp.yaml"
  group_file="psp_group.yaml"
  if [ -e "$psp_file" ]; then
    error "Error: ${psp_file} already existed"
    exit 1
  fi
  if [ -e "$group_file" ]; then
    error "Error: ${psp_file} already existed"
    exit 1
  fi

  namespaces=$($KUBECTL get ns | awk '{if (NR>1) print $1}')
  # shellcheck disable=SC2068
  for namespace in ${namespaces[@]}; do
    if [[ "$namespace" == "default" ]]; then
      continue
    fi
    cat >>$group_file <<EOF
- kind: Group
  name: system:serviceaccounts:$namespace
  apiGroup: rbac.authorization.k8s.io
EOF
  done

  if [ -e "$group_file" ]; then
    cat >>$psp_file <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: psp-privileged
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: privileged-psp
subjects:
$(cat $group_file)
EOF
  fi
  # shellcheck disable=SC2005
  echo "$(cat $psp_file)"

  # clear tmp file
  rm $psp_file
  rm $group_file
}

function create-psp() {
  privileged_psp_file=privileged-psp.yaml
  if [ -e "$privileged_psp_file" ]; then
    error "Error: $privileged_psp_file already existed"
    exit 1
  fi

  cat <<EOF | kubectl apply -f -
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: restricted-psp
spec:
  privileged: false
  allowPrivilegeEscalation: false
  seLinux:
    rule: RunAsAny
  runAsUser:
    rule: MustRunAsNonRoot
  fsGroup:
    rule: MustRunAs
    ranges:
    - min: 1
      max: 65535
  supplementalGroups:
    rule: MustRunAs
    ranges:
    - min: 1
      max: 65535
  readOnlyRootFilesystem: true
  hostNetwork: false
  hostIPC: false
  hostPID: false
  volumes:
  - 'configMap'
  - 'emptyDir'
  - 'projected'
  - 'secret'
  - 'downwardAPI'
  - 'csi'
  - 'persistentVolumeClaim'
EOF

  cat <<EOF | kubectl apply -f -
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: privileged-psp
spec:
  privileged: true
  hostNetwork: true
  allowPrivilegeEscalation: true
  defaultAllowPrivilegeEscalation: true
  hostPID: true
  hostIPC: true
  runAsUser:
    rule: RunAsAny
  fsGroup:
    rule: RunAsAny
  seLinux:
    rule: RunAsAny
  supplementalGroups:
    rule: RunAsAny
  volumes:
  - '*'
  allowedCapabilities:
  - '*'
EOF

  cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: restricted-psp
rules:
- apiGroups:
  - policy
  resources:
  - podsecuritypolicies
  verbs:
  - use
  resourceNames:
  - restricted-psp
EOF

  n=1
  while (($n < 10)); do
    restricted_role=$($KUBECTL get clusterRole restricted-psp 2>/dev/null)
    if [[ "$restricted_role" != "" ]]; then
      break
    fi
    ((n++))
    sleep 1
  done

  cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: privileged-psp
rules:
- apiGroups:
  - policy
  resources:
  - podsecuritypolicies
  verbs:
  - use
  resourceNames:
  - privileged-psp
EOF

  n=1
  while (($n < 10)); do
    privileged_role=$($KUBECTL get clusterRole privileged-psp 2>/dev/null)
    if [[ "$privileged_role" != "" ]]; then
      break
    fi
    ((n++))
    sleep 1
  done

  cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: psp-global
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: restricted-psp
subjects:
- kind: Group
  name: system:serviceaccounts
  apiGroup: rbac.authorization.k8s.io
EOF

  # shellcheck disable=SC2005
  echo "$(privileged-template)" >>$privileged_psp_file
  kubectl apply -f $privileged_psp_file
  rm $privileged_psp_file
}

function delete-psp() {
  $KUBECTL get clusterRoleBinding | grep psp | awk '{print $1}' | xargs -I {} kubectl delete clusterRoleBinding {}
  $KUBECTL get clusterRole | grep psp | awk '{print $1}' | xargs -I {} kubectl delete clusterRole {}
  $KUBECTL get psp | awk '{print $1}' | awk '{if (NR>1) print $1}' | xargs -I {} kubectl delete psp {}
}

function test-sa() {
  namespaces=$($KUBECTL get ns | awk '{if (NR>1) print $1}')
  psps=$($KUBECTL get psp | awk '{if (NR>1) print $1}')
  # shellcheck disable=SC2068
  for namespace in ${namespaces[@]}; do
    sas=$($KUBECTL get sa -n $namespace | awk '{if (NR>1) print $1}')
    for sa in ${sas[@]}; do
      for psp in ${psps[@]}; do
        permit=$($KUBECTL auth can-i use podsecuritypolicy/$psp \
          --as=system:serviceaccount:$namespace:$sa -A)
        if [[ "$permit" = "yes" ]]; then
          echo "$namespace:$sa -> $psp ✅"
        else
          echo "$namespace:$sa -> $psp ❌"
        fi
      done
    done
  done
}

function test-psp() {
  namespace=${1:-default}
  message "Namespace: $namespace"
  # 查询 apiserver 地址
  apiserver=""
  host=$($KUBECTL get nodes -o wide | awk '{if (NR==2) print $6 }')
  if [ "$host" = "" ]; then
    error "Error: unresolved apiserver address"
    exit 1
  else
    apiserver=$host:6443
  fi

  sa=test-sa
  role=test-pod-create-role
  role_binding=test-pod-create-role-binding

  # 1. 创建 sa
  $KUBECTL create sa $sa -n $namespace

  # 2. 创建 Role
  cat <<EOF | $KUBECTL apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: $namespace
  name: $role
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "watch", "list", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
EOF

  # 3. 创建 RoleBinding
  cat <<EOF | $KUBECTL apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: $role_binding
  namespace: $namespace
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: $role
subjects:
- kind: ServiceAccount
  name: $sa
  namespace: $namespace
EOF

  # 4. 获取sa的token
  # shellcheck disable=SC2046
  token=$($KUBECTL get secrets $($KUBECTL get sa $sa -n $namespace -o=jsonpath="{.secrets[*].name}") -n $namespace -o=jsonpath={.data.token} | base64 -d)

  # 5. 查询 sa 的访问权限
  # shellcheck disable=SC2046
  $KUBECTL --token=$token --kubeconfig=/dev/null --server="https://${apiserver}" --insecure-skip-tls-verify=true auth can-i --list

  # 6. 创建特权pod
  cat <<EOF | $KUBECTL --token=$token --kubeconfig=/dev/null --server="https://${apiserver}" --insecure-skip-tls-verify=true apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
  namespace: $namespace
spec:
  containers:
  - name: nginx-container
    image: nginx
    securityContext:
      privileged: true
EOF

  # 7. clear test env
  $KUBECTL delete pod test-pod -n $namespace
  $KUBECTL delete RoleBinding $role_binding -n $namespace
  $KUBECTL delete Role $role -n $namespace
  $KUBECTL delete sa $sa -n $namespace
}

case "$1" in
create)
  create-psp
  ;;
delete)
  delete-psp
  ;;
test-sa)
  test-sa
  ;;
test-psp)
  test-psp $2
  ;;
tpl)
  privileged-template
  ;;
esac
