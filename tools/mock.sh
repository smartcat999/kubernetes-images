#!/usr/bin/env bash

# 1. 创建 nodegroup 资源
#   ./mock.sh create

# 2. 删除某个 nodegroup
#   ./mock.sh delete ${nodegroup}

# 3. 清理环境
#   ./mock.sh clean

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

KS_APISERVER=""
MEMBER_CLUSTER=""
KS_USER=${KS_USER:-}
KS_PASS=${KS_PASS:-}
if [ "$KS_USER" = "" ] || [ "$KS_PASS" = "" ]; then
  error "Please set KS_USER=user KS_PASS=*** !"
  exit 1
fi

function discover-ks-apiserver() {
  apiserver=$(kubectl -n kubesphere-system get pods -o wide -l app=ks-apiserver | awk '{if ( NR>1 ) print $6 }')
  export KS_APISERVER=http://$apiserver:9090
}

function oauth() {
  token=$(curl --location "$KS_APISERVER/oauth/token" \
    --header "Content-Type: application/x-www-form-urlencoded" \
    --data-urlencode "username=$KS_USER" \
    --data-urlencode "password=$KS_PASS" \
    --data-urlencode "client_id=kubesphere" \
    --data-urlencode "grant_type=password" \
    --data-urlencode "client_secret=kubesphere" | jq .access_token | sed 's/"//g')
  export KS_TOKEN=$token
}

# init api info/token
discover-ks-apiserver
oauth

echo KS_APISERVER: $KS_APISERVER
echo KS_TOKEN: $KS_TOKEN

function create-nodegroup() {
  nodegroup=$1
  message "create-nodegroup: $nodegroup"
  url="$KS_APISERVER/kapis/infra.kubesphere.io/v1alpha1/nodegroups"
  if [ "$MEMBER_CLUSTER" != "" ]; then
    url="$KS_APISERVER/kapis/clusters/$MEMBER_CLUSTER/infra.kubesphere.io/v1alpha1/nodegroups"
  fi

  curl --location $url \
    --header 'Content-Type: application/json' \
    --header "Authorization: Bearer $KS_TOKEN" \
    --data '{
      "apiVersion": "infro.kubesphere.io/v1alpha1",
      "kind": "NodeGroup",
      "metadata": {
          "name": "'"$nodegroup"'"
      },
      "spec": {
          "alias": "'"$nodegroup"'",
          "description": "'"$nodegroup"'",
          "manager": "admin"
      },
      "status": {
          "state": "active"
      }
  }'
}

function delete-nodegroup() {
  nodegroup=$1
  message "delete-nodegroup: $nodegroup"
  if [ "$MEMBER_CLUSTER" != "" ]; then
    url="$KS_APISERVER/kapis/clusters/$MEMBER_CLUSTER/infra.kubesphere.io/v1alpha1/nodegroups/$nodegroup"
  fi
  url="$KS_APISERVER/kapis/infra.kubesphere.io/v1alpha1/nodegroups/$nodegroup"
  curl --location --request DELETE $url \
    --header "Authorization: Bearer $KS_TOKEN"
}

function create-vnode() {
  node=$1
  message "create-vnode: $node"
  cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Node
metadata:
  annotations:
    node.alpha.kubernetes.io/ttl: "0"
    volumes.kubernetes.io/controller-managed-attach-detach: "true"
  labels:
    beta.kubernetes.io/arch: amd64
    beta.kubernetes.io/os: linux
    kubernetes.io/arch: amd64
    kubernetes.io/hostname: $node
    kubernetes.io/os: linux
    node-role.kubernetes.io/control-plane: ""
    node-role.kubernetes.io/worker: ""
    node.kubernetes.io/exclude-from-external-load-balancers: ""
    vnode: "mock"
  name: $node
spec: {}
status: {}
EOF
}

function delete-vnode() {
  message "delete-vnode"
  kubectl get nodes -l vnode=mock | awk '{if (NR>1) print $1}' | xargs kubectl delete node
}

function bind-nodegroup-namespace() {
  nodegroup=$1
  namespace=$2
  message "bind-nodegroup-namespace: $nodegroup $namespace"
  if [ "$MEMBER_CLUSTER" != "" ]; then
    url="$KS_APISERVER/kapis/clusters/infra.kubesphere.io/v1alpha1/nodegroups/$nodegroup/namespaces/$namespace"
  fi
  url="$KS_APISERVER/kapis/infra.kubesphere.io/v1alpha1/nodegroups/$nodegroup/namespaces/$namespace"

  curl --location --request POST $url \
    --header "Authorization: Bearer $KS_TOKEN"
}

function bind-nodegroup-node() {
  nodegroup=$1
  node=$2
  message "bind-nodegroup-node: $nodegroup $node"
  if [ "$MEMBER_CLUSTER" != "" ]; then
    url="$KS_APISERVER/kapis/clusters/infra.kubesphere.io/v1alpha1/nodegroups/$nodegroup/nodes/$node"
  fi
  url="$KS_APISERVER/kapis/infra.kubesphere.io/v1alpha1/nodegroups/$nodegroup/nodes/$node"

  curl --location --request POST $url \
    --header "Authorization: Bearer $KS_TOKEN"
}

function init-crd() {
  cat <<EOF | kubectl apply -f -
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  annotations:
    controller-gen.kubebuilder.io/version: (devel)
  creationTimestamp: null
  name: nodegrouproles.iam.kubesphere.io
spec:
  group: iam.kubesphere.io
  names:
    categories:
    - iam
    kind: NodeGroupRole
    listKind: NodeGroupRoleList
    plural: nodegrouproles
    singular: nodegrouprole
  scope: Cluster
  versions:
  - name: v1alpha2
    schema:
      openAPIV3Schema:
        properties:
          apiVersion:
            description: 'APIVersion defines the versioned schema of this representation
              of an object. Servers should convert recognized schemas to the latest
              internal value, and may reject unrecognized values. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources'
            type: string
          kind:
            description: 'Kind is a string value representing the REST resource this
              object represents. Servers may infer this from the endpoint the client
              submits requests to. Cannot be updated. In CamelCase. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds'
            type: string
          metadata:
            type: object
          rules:
            description: Rules holds all the PolicyRules for this NodeGroupRole
            items:
              description: PolicyRule holds information that describes a policy rule,
                but does not contain information about who the rule applies to or
                which namespace the rule applies to.
              properties:
                apiGroups:
                  description: APIGroups is the name of the APIGroup that contains
                    the resources.  If multiple API groups are specified, any action
                    requested against one of the enumerated resources in any API group
                    will be allowed.
                  items:
                    type: string
                  type: array
                nonResourceURLs:
                  description: NonResourceURLs is a set of partial urls that a user
                    should have access to.  *s are allowed, but only as the full,
                    final step in the path Since non-resource URLs are not namespaced,
                    this field is only applicable for ClusterRoles referenced from
                    a ClusterRoleBinding. Rules can either apply to API resources
                    (such as "pods" or "secrets") or non-resource URL paths (such
                    as "/api"),  but not both.
                  items:
                    type: string
                  type: array
                resourceNames:
                  description: ResourceNames is an optional white list of names that
                    the rule applies to.  An empty set means that everything is allowed.
                  items:
                    type: string
                  type: array
                resources:
                  description: Resources is a list of resources this rule applies
                    to.  ResourceAll represents all resources.
                  items:
                    type: string
                  type: array
                verbs:
                  description: Verbs is a list of Verbs that apply to ALL the ResourceKinds
                    and AttributeRestrictions contained in this rule.  VerbAll represents
                    all kinds.
                  items:
                    type: string
                  type: array
              required:
              - verbs
              type: object
            type: array
        type: object
    served: true
    storage: true
status:
  acceptedNames:
    kind: ""
    plural: ""
  conditions: []
  storedVersions: []

---

---
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  annotations:
    controller-gen.kubebuilder.io/version: (devel)
  creationTimestamp: null
  name: nodegrouprolebindings.iam.kubesphere.io
spec:
  group: iam.kubesphere.io
  names:
    categories:
    - iam
    kind: NodeGroupRoleBinding
    listKind: NodeGroupRoleBindingList
    plural: nodegrouprolebindings
    singular: nodegrouprolebinding
  scope: Cluster
  versions:
  - name: v1alpha2
    schema:
      openAPIV3Schema:
        properties:
          apiVersion:
            description: 'APIVersion defines the versioned schema of this representation
              of an object. Servers should convert recognized schemas to the latest
              internal value, and may reject unrecognized values. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources'
            type: string
          kind:
            description: 'Kind is a string value representing the REST resource this
              object represents. Servers may infer this from the endpoint the client
              submits requests to. Cannot be updated. In CamelCase. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds'
            type: string
          metadata:
            type: object
          roleRef:
            description: RoleRef can only reference a WorkspaceRole. If the RoleRef
              cannot be resolved, the Authorizer must return an error.
            properties:
              apiGroup:
                description: APIGroup is the group for the resource being referenced
                type: string
              kind:
                description: Kind is the type of resource being referenced
                type: string
              name:
                description: Name is the name of resource being referenced
                type: string
            required:
            - apiGroup
            - kind
            - name
            type: object
          subjects:
            description: Subjects holds references to the objects the role applies
              to.
            items:
              description: Subject contains a reference to the object or user identities
                a role binding applies to.  This can either hold a direct API object
                reference, or a value for non-objects such as user and group names.
              properties:
                apiGroup:
                  description: APIGroup holds the API group of the referenced subject.
                    Defaults to "" for ServiceAccount subjects. Defaults to "rbac.authorization.k8s.io"
                    for User and Group subjects.
                  type: string
                kind:
                  description: Kind of object being referenced. Values defined by
                    this API group are "User", "Group", and "ServiceAccount". If the
                    Authorizer does not recognized the kind value, the Authorizer
                    should report an error.
                  type: string
                name:
                  description: Name of the object being referenced.
                  type: string
                namespace:
                  description: Namespace of the referenced object.  If the object
                    kind is non-namespace, such as "User" or "Group", and this value
                    is not empty the Authorizer should report an error.
                  type: string
              required:
              - kind
              - name
              type: object
            type: array
        required:
        - roleRef
        type: object
    served: true
    storage: true
status:
  acceptedNames:
    kind: ""
    plural: ""
  conditions: []
  storedVersions: []

---

---
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  annotations:
    controller-gen.kubebuilder.io/version: (devel)
  creationTimestamp: null
  name: nodegroups.infra.kubesphere.io
spec:
  group: infra.kubesphere.io
  names:
    kind: NodeGroup
    listKind: NodeGroupList
    plural: nodegroups
    singular: nodegroup
  scope: Cluster
  versions:
  - name: v1alpha1
    schema:
      openAPIV3Schema:
        properties:
          apiVersion:
            description: 'APIVersion defines the versioned schema of this representation
              of an object. Servers should convert recognized schemas to the latest
              internal value, and may reject unrecognized values. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources'
            type: string
          kind:
            description: 'Kind is a string value representing the REST resource this
              object represents. Servers may infer this from the endpoint the client
              submits requests to. Cannot be updated. In CamelCase. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds'
            type: string
          metadata:
            type: object
          spec:
            description: NodeGroupSpec defines the desired state of NodeGroup
            properties:
              alias:
                description: Alias of NodeGroup
                type: string
              description:
                description: Description of NodeGroup
                type: string
              manager:
                description: Manager of NodeGroup
                type: string
            type: object
          status:
            description: NodeGroupStatus defines the observed state of NodeGroup
            properties:
              state:
                description: 'INSERT ADDITIONAL STATUS FIELD - define observed state
                  of cluster Important: Run "make" to regenerate code after modifying
                  this file'
                type: string
            type: object
        type: object
    served: true
    storage: true
status:
  acceptedNames:
    kind: ""
    plural: ""
  conditions: []
  storedVersions: []
EOF
}

function create-role-template() {
  # create GlobalRole
  cat <<EOF | kubectl apply -f -
apiVersion: iam.kubesphere.io/v1alpha2
kind: GlobalRole
metadata:
  annotations:
    iam.kubesphere.io/module: Access Control
    iam.kubesphere.io/role-template-rules: '{"nodegroups": "view"}'
    kubesphere.io/alias-name: NodeGroups View
  labels:
    iam.kubesphere.io/role-template: 'true'
    kubefed.io/managed: 'true'
  name: role-template-view-nodegroups
rules:
  - apiGroups:
      - 'infra.kubesphere.io'
    resources:
      - 'nodegroups'
      - 'nodes'
      - 'namespaces'
    verbs:
      - 'list'
      - 'get'
      - 'watch'
  - apiGroups:
      - 'iam.kubesphere.io'
    resources:
      - 'roles'
      - 'members'
      - 'members/nodegrouproles'
    verbs:
      - 'list'
      - 'get'
      - 'watch'

---
apiVersion: iam.kubesphere.io/v1alpha2
kind: GlobalRole
metadata:
  annotations:
    iam.kubesphere.io/dependencies: '["role-template-view-nodegroups"]'
    iam.kubesphere.io/module: Access Control
    iam.kubesphere.io/role-template-rules: '{"nodegroups": "manage"}'
    kubesphere.io/alias-name: NodeGroups Management
  labels:
    iam.kubesphere.io/role-template: 'true'
    kubefed.io/managed: 'true'
  name: role-template-manage-nodegroups
rules:
  - apiGroups:
      - 'infra.kubesphere.io'
    resources:
      - 'nodegroups'
      - 'nodes'
      - 'namespaces'
    verbs:
      - '*'
  - apiGroups:
      - 'iam.kubesphere.io'
    resources:
      - 'roles'
      - 'members'
      - 'members/nodegrouproles'
    verbs:
      - '*'
EOF
  # create NodeGroupRole role-template
  cat <<EOF | kubectl apply -f -
apiVersion: iam.kubesphere.io/v1alpha2
kind: NodeGroupRole
metadata:
  annotations:
    iam.kubesphere.io/module: Access Control
    iam.kubesphere.io/role-template-rules: '{"nodegroups": "view"}'
    kubesphere.io/alias-name: NodeGroups View
  labels:
    iam.kubesphere.io/role-template: 'true'
  name: role-template-view-nodegroups
rules:
  - apiGroups:
      - 'infra.kubesphere.io'
    resources:
      - 'nodegroups'
      - 'nodes'
      - 'namespaces'
    verbs:
      - 'get'
      - 'list'
      - 'watch'

---
apiVersion: iam.kubesphere.io/v1alpha2
kind: NodeGroupRole
metadata:
  annotations:
    iam.kubesphere.io/dependencies: '["role-template-view-nodegroups"]'
    iam.kubesphere.io/module: Access Control
    iam.kubesphere.io/role-template-rules: '{"nodegroups": "manage"}'
    kubesphere.io/alias-name: NodeGroups Management
  labels:
    iam.kubesphere.io/role-template: 'true'
  name: role-template-manage-nodegroups
rules:
  - apiGroups:
      - 'infra.kubesphere.io'
    resources:
      - 'nodegroups'
    verbs:
      - '*'
  - apiGroups:
      - 'iam.kubesphere.io'
    resources:
      - 'roles'
      - 'members'
      - 'members/nodegrouproles'
    verbs:
      - '*'
EOF

  # init RoleBase
  cat <<EOF | kubectl apply -f -
apiVersion: iam.kubesphere.io/v1alpha2
kind: RoleBase
metadata:
  name: nodegroup-viewer
role:
  apiVersion: iam.kubesphere.io/v1alpha2
  kind: NodeGroupRole
  metadata:
    annotations:
      iam.kubesphere.io/aggregation-roles: '["role-template-view-nodegroups"]'
      kubesphere.io/creator: system
    name: viewer
  rules:
    - apiGroups:
        - 'infra.kubesphere.io'
      resources:
        - 'nodegroups'
        - 'nodes'
        - 'namespaces'
      verbs:
        - 'get'
        - 'list'
        - 'watch'

---
apiVersion: iam.kubesphere.io/v1alpha2
kind: RoleBase
metadata:
  name: nodegroup-admin
role:
  apiVersion: iam.kubesphere.io/v1alpha2
  kind: NodeGroupRole
  metadata:
    annotations:
      iam.kubesphere.io/aggregation-roles: '["role-template-manage-nodegroups","role-template-view-nodegroups"]'
      kubesphere.io/creator: system
    name: admin
  rules:
    - apiGroups:
        - 'infra.kubesphere.io'
      resources:
        - 'nodegroups'
      verbs:
        - '*'
    - apiGroups:
        - 'iam.kubesphere.io'
      resources:
        - 'roles'
        - 'members'
        - 'members/nodegrouproles'
      verbs:
        - '*'
EOF
}

function delete-role-template() {
  kubectl delete GlobalRole role-template-view-nodegroups role-template-manage-nodegroups
  kubectl delete RoleBase nodegroup-viewer nodegroup-admin
  #  kubectl delete NodeGroupRole role-template-view-nodegroups role-template-manage-nodegroups
}

# create NodeGroupRole
function create-nodegroup-role() {
  nodegroup=$1
  cat <<EOF | kubectl apply -f -
apiVersion: iam.kubesphere.io/v1alpha2
kind: NodeGroupRole
metadata:
  annotations:
    iam.kubesphere.io/aggregation-roles: >-
      ["role-template-view-nodegroups"]
    kubesphere.io/creator: system
  labels:
    kubesphere.io/nodegroup: $nodegroup
  name: $nodegroup-viewer
rules:
  - apiGroups:
      - '*'
    resources:
      - '*'
    verbs:
      - get
      - list
      - watch

---
apiVersion: iam.kubesphere.io/v1alpha2
kind: NodeGroupRole
metadata:
  annotations:
    iam.kubesphere.io/aggregation-roles: >-
      ["role-template-manage-nodegroups", "role-template-view-nodegroups"]
    kubesphere.io/creator: system
  labels:
    kubesphere.io/nodegroup: $nodegroup
  name: $nodegroup-admin
rules:
  - apiGroups:
      - '*'
    resources:
      - '*'
    verbs:
      - '*'
EOF
}

function delete-nodegroup-role() {
  nodegroup=$1
  kubectl delete NodeGroupRole $nodegroup-viewer $nodegroup-admin
}

case "$1" in
"create")
  init-crd
  create-role-template
  for ((i = 1; i < 10; i++)); do
    create-nodegroup nodegroup0$i
    create-vnode vnode0$i
  done

  for ((i = 1; i < 10; i++)); do
    cur_nodegroup=nodegroup0$i
    bind-nodegroup-namespace $cur_nodegroup default
    bind-nodegroup-node $cur_nodegroup vnode0$i
  done
  ;;
"delete")
  delete-nodegroup $2
  ;;
"clean")
  for ((i = 1; i < 10; i++)); do
    delete-nodegroup nodegroup0$i
  done

  delete-role-template
  delete-vnode
  ;;
esac
