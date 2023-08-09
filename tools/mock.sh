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
  apiserver=$(kubectl -n kubesphere-system get pods -l app=ks-apiserver -o jsonpath="{.items[0].status.podIP}")
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

function create-node() {
  NODE=$1
  USER=$2
  HOST=$3
  NODEGROUP=$4
  RUNTIME=docker
  ADD_DEFAULT_TAINT=true
  message "create-node: $NODE($USER@$HOST)"
  if [ "$MEMBER_CLUSTER" != "" ]; then
    url="$KS_APISERVER/kapis/clusters/$MEMBER_CLUSTER/infra.edgewize.io/v1alpha1/nodes/join"
  fi
  url="$KS_APISERVER/kapis/infra.edgewize.io/v1alpha1/nodes/join"

  command=$(curl "$url?node_name=$NODE&add_default_taint=$ADD_DEFAULT_TAINT&runtime=$RUNTIME" \
    -H 'Accept: */*' \
    -H 'Accept-Language: zh-CN,zh;q=0.9' \
    -H 'Connection: keep-alive' \
    -H "Authorization: Bearer $KS_TOKEN" \
    -H 'content-type: application/json' \
    --compressed \
    --insecure)
  echo $command

  ssh $USER@$HOST "curl https://get.docker.com | bash"
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

function init-federated-crd() {
  # init federatedtypeconfigs
  cat <<EOF | kubectl apply -f -
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  creationTimestamp: null
  name: federatedtypeconfigs.core.kubefed.io
spec:
  group: core.kubefed.io
  names:
    kind: FederatedTypeConfig
    listKind: FederatedTypeConfigList
    plural: federatedtypeconfigs
    shortNames:
    - ftc
    singular: federatedtypeconfig
  scope: Namespaced
  versions:
  - name: v1beta1
    schema:
      openAPIV3Schema:
        description: "FederatedTypeConfig programs KubeFed to know about a single
          API type - the \"target type\" - that a user wants to federate. For each
          target type, there is a corresponding FederatedType that has the following
          fields: \n - The \"template\" field specifies the basic definition of a
          federated resource - The \"placement\" field specifies the placement information
          for the federated   resource - The \"overrides\" field specifies how the
          target resource should vary across   clusters."
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
            description: FederatedTypeConfigSpec defines the desired state of FederatedTypeConfig.
            properties:
              federatedType:
                description: Configuration for the federated type that defines (via
                  template, placement and overrides fields) how the target type should
                  appear in multiple cluster.
                properties:
                  group:
                    description: Group of the resource.
                    type: string
                  kind:
                    description: Camel-cased singular name of the resource (e.g. ConfigMap)
                    type: string
                  pluralName:
                    description: Lower-cased plural name of the resource (e.g. configmaps).  If
                      not provided, it will be computed by lower-casing the kind and
                      suffixing an 's'.
                    type: string
                  scope:
                    description: Scope of the resource.
                    type: string
                  version:
                    description: Version of the resource.
                    type: string
                required:
                - kind
                - pluralName
                - scope
                - version
                type: object
              propagation:
                description: Whether or not propagation to member clusters should
                  be enabled.
                type: string
              statusCollection:
                description: Whether or not Status object should be populated.
                type: string
              statusType:
                description: Configuration for the status type that holds information
                  about which type holds the status of the federated resource. If
                  not provided, the group and version will default to those provided
                  for the federated type api resource.
                properties:
                  group:
                    description: Group of the resource.
                    type: string
                  kind:
                    description: Camel-cased singular name of the resource (e.g. ConfigMap)
                    type: string
                  pluralName:
                    description: Lower-cased plural name of the resource (e.g. configmaps).  If
                      not provided, it will be computed by lower-casing the kind and
                      suffixing an 's'.
                    type: string
                  scope:
                    description: Scope of the resource.
                    type: string
                  version:
                    description: Version of the resource.
                    type: string
                required:
                - kind
                - pluralName
                - scope
                - version
                type: object
              targetType:
                description: The configuration of the target type. If not set, the
                  pluralName and groupName fields will be set from the metadata.name
                  of this resource. The kind field must be set.
                properties:
                  group:
                    description: Group of the resource.
                    type: string
                  kind:
                    description: Camel-cased singular name of the resource (e.g. ConfigMap)
                    type: string
                  pluralName:
                    description: Lower-cased plural name of the resource (e.g. configmaps).  If
                      not provided, it will be computed by lower-casing the kind and
                      suffixing an 's'.
                    type: string
                  scope:
                    description: Scope of the resource.
                    type: string
                  version:
                    description: Version of the resource.
                    type: string
                required:
                - kind
                - pluralName
                - scope
                - version
                type: object
            required:
            - federatedType
            - propagation
            - targetType
            type: object
          status:
            description: FederatedTypeConfigStatus defines the observed state of FederatedTypeConfig
            properties:
              observedGeneration:
                description: ObservedGeneration is the generation as observed by the
                  controller consuming the FederatedTypeConfig.
                format: int64
                type: integer
              propagationController:
                description: PropagationController tracks the status of the sync controller.
                type: string
              statusController:
                description: StatusController tracks the status of the status controller.
                type: string
            required:
            - observedGeneration
            - propagationController
            type: object
        required:
        - spec
        type: object
    served: true
    storage: true
    subresources:
      status: {}
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
  - apiGroups:
      - 'resources.kubesphere.io'
    resources:
      - 'namespaces'
      - 'services'
    verbs:
      - 'get'
      - 'list'
      - 'watch'
  - apiGroups:
      - 'iam.kubesphere.io'
    resources:
      - 'roles'
      - 'members'
    verbs:
      - 'get'
      - 'list'
      - 'watch'
  - apiGroups:
      - 'monitoring.kubesphere.io'
    resources:
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
  - apiGroups:
      - 'resources.kubesphere.io'
    resources:
      - 'namespaces'
      - 'services'
    verbs:
      - '*'
  - apiGroups:
      - 'iam.kubesphere.io'
    resources:
      - 'roles'
      - 'members'
    verbs:
      - '*'
  - apiGroups:
      - 'monitoring.kubesphere.io'
    resources:
      - 'namespaces'
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
    - apiGroups:
        - 'resources.kubesphere.io'
      resources:
        - 'namespaces'
        - 'services'
      verbs:
        - 'get'
        - 'list'
        - 'watch'
    - apiGroups:
        - 'iam.kubesphere.io'
      resources:
        - 'roles'
        - 'members'
      verbs:
        - 'get'
        - 'list'
        - 'watch'
    - apiGroups:
        - 'monitoring.kubesphere.io'
      resources:
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
    - apiGroups:
        - 'resources.kubesphere.io'
      resources:
        - 'namespaces'
        - 'services'
      verbs:
        - '*'
    - apiGroups:
        - 'iam.kubesphere.io'
      resources:
        - 'roles'
        - 'members'
      verbs:
        - '*'
    - apiGroups:
        - 'monitoring.kubesphere.io'
      resources:
        - 'namespaces'
      verbs:
        - '*'
EOF

# init clusterrole
cat <<EOF | kubectl --kubeconfig=wuhan1.vcluster.config apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  annotations:
    kubesphere.io/creator: system
    kubesphere.io/description: "查看集群中的节点组"
    iam.kubesphere.io/aggregation-roles: '[]'
  name: cluster-regular
rules:
- apiGroups:
    - 'infra.edgewize.io'
  resources:
    - '*'
  verbs:
    - get
    - list
    - watch
- apiGroups:
    - infra.kubesphere.io
  resources:
    - '*'
  verbs:
    - get
    - list
    - watch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  annotations:
    kubesphere.io/creator: system
    kubesphere.io/description: "管理集群中的节点组"
    iam.kubesphere.io/aggregation-roles: '[]'
  name: cluster-self-provisioner
rules:
- apiGroups:
    - 'infra.edgewize.io'
  resources:
    - '*'
  verbs:
    - '*'
- apiGroups:
    - infra.kubesphere.io
  resources:
    - '*'
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
init-crd)
  init-crd
  create-role-template
  ;;
init-node)
  # shellcheck disable=SC2002
  create-node "edgenode-$(cat /proc/sys/kernel/random/uuid  | md5sum |cut -c 1-9)" root 172.31.73.72
#  create-node "edgenode-$(cat /proc/sys/kernel/random/uuid  | md5sum |cut -c 1-9)" root 172.31.73.180
#  create-node "edgenode-$(cat /proc/sys/kernel/random/uuid  | md5sum |cut -c 1-9)" root 172.31.73.184
  ;;
create)
  init-crd
  create-role-template
  for ((i = 1; i < 10; i++)); do
    create-nodegroup nodegroup0$i
#    create-vnode vnode0$i
  done

  for ((i = 1; i < 10; i++)); do
    cur_nodegroup=nodegroup0$i
    bind-nodegroup-namespace $cur_nodegroup default
    bind-nodegroup-node $cur_nodegroup vnode0$i
  done
  ;;
delete)
  delete-nodegroup $2
  ;;
clean)
  for ((i = 1; i < 10; i++)); do
    delete-nodegroup nodegroup0$i
  done

  delete-role-template
  delete-vnode
  ;;
esac
