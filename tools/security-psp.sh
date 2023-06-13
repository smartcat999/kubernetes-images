#!/bin/bash

# [debug=true/false] security-psp.sh [create/delete/test]
# 1. 创建psp
# ./security-psp.sh create

# 2. 删除psp
# ./security-psp.sh delete

# 3. 检查sa访问psp的权限
# ./security-psp.sh test

if [ ${debug:-false} = true ]; then
  set -x
fi

KUBECTL=${KUBECTL:-/usr/local/bin/kubectl}

function create-psp() {
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

  namespaces=$($KUBECTL get ns | awk '{if (NR>1) print $1}')
  # shellcheck disable=SC2068
  for namespace in ${namespaces[@]}; do
    if [[ "$namespace" != "kubesphere-system" ]] && \
    [[ "$namespace" != "kubesphere-monitoring-system" ]] && \
    [[ "$namespace" != "kubesphere-monitoring-federated" ]]; then
      #    echo "find namespace: ${namespace}"
      continue
    fi
    echo "add ClusterRoleBinding "
    cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: psp-$namespace
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: privileged-psp
subjects:
- kind: Group
  name: system:serviceaccounts:$namespace
  apiGroup: rbac.authorization.k8s.io
EOF
  done
}

function delete-psp() {
  $KUBECTL get clusterRoleBinding | grep psp | awk '{print $1}' | xargs -I {} kubectl delete clusterRoleBinding {}
  $KUBECTL get clusterRole | grep psp | awk '{print $1}' | xargs -I {} kubectl delete clusterRole {}
  $KUBECTL get psp | awk '{print $1}' | awk '{if (NR>1) print $1}' | xargs -I {} kubectl delete psp {}
}

function test-sa() {
  namespaces=$($KUBECTL get ns | awk '{if (NR>1) print $1}')
  # shellcheck disable=SC2068
  for namespace in ${namespaces[@]}; do
    sas=$($KUBECTL get sa -n $namespace | awk '{if (NR>1) print $1}')
    for sa in ${sas[@]}; do
      permit=$($KUBECTL auth can-i use podsecuritypolicy/restricted-psp \
        --as=system:serviceaccount:$namespace:$sa -A)
      if [[ "$permit" = "yes" ]]; then
        echo "$namespace:$sa -> restricted-psp ✅"
      else
        echo "$namespace:$sa -> restricted-psp ❌"
      fi

      permit=$($KUBECTL auth can-i use podsecuritypolicy/privileged-psp \
        --as=system:serviceaccount:$namespace:$sa -A)
      if [[ "$permit" = "yes" ]]; then
        echo "$namespace:$sa -> privileged-psp ✅"
      else
        echo "$namespace:$sa -> privileged-psp ❌"
      fi
    done
  done
}

case "$1" in
create)
  create-psp
  ;;
delete)
  delete-psp
  ;;
test)
  test-sa
  ;;
esac
