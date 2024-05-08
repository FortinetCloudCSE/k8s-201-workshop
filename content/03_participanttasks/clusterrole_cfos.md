---
title: "Deep Dive into RoleBindings and ClusterRoleBindings"
chapter: false
menuTitle: "Difference Between RoleBindings and ClusterRoleBindings"
weight: 2
---

## Objective

Learn how to create and bind a Role to a cFOS POD for cFOS to operate Kubernetes resources.

### What are Role and RoleBinding?

Kubernetes uses roles and cluster roles to manage authorization, specifying what actions a user or service account can perform within the cluster. This is part of Kubernetes' Role-Based Access Control (RBAC) system, which ensures secure access to the cluster's resources. By clearly defining permissions, Kubernetes can enforce policies that restrict who can read, modify, or delete resources, either within a single namespace or across the entire cluster.

- **Role**: 
  A Role is crucial when a Pod needs to access Kubernetes API resources such as ConfigMaps or Secrets within a specific namespace. It defines permissions that are limited to one namespace, enhancing security by restricting access scope.

- **RoleBinding**: 
  A RoleBinding is necessary to link a Role to a Service Account within a namespace. This linkage grants the associated Pod the permissions defined by the Role, enabling it to perform specified actions within that namespace.

- **ClusterRole**:
  A ClusterRole extends the concept of Roles by providing permissions that are applicable across the entire cluster or on cluster-wide resources. This is useful for Pods that require broader access to resources or need to perform actions that span multiple namespaces.

- **ClusterRoleBinding**:
  This binds a ClusterRole to a Service Account, giving the associated Pods permissions across all namespaces or for cluster-wide resources. It’s essential for applications that operate on a larger scale within the cluster.

- **API Groups**:
  Kubernetes organizes APIs into groups to streamline extensions and upgrades, categorizing resources to help manage the API's evolution. API groups allow users to extend the Kubernetes API with their own resources logically. Within these groups, verbs define permissible actions on the resources. Verbs such as `get`, `list`, `watch`, `create`, `update`, and `delete` define what operations are permitted on the resources managed through the API. These verbs are specified in Roles and ClusterRoles to grant precise control over how resources are accessed and manipulated, ensuring that permissions are exactly aligned with user or application requirements.

- **Service Account**: 
  Service Accounts are used by Pods to authenticate against the Kubernetes API, ensuring that API calls are securely identified and appropriately authorized based on the assigned roles and permissions.

- **Scope**: 
  Scope in Kubernetes defines the extent of access control settings, either within a single namespace or across the entire cluster, helping in the effective management and isolation of resources.

- **Namespace**: 
  Namespaces are a core organizational feature in Kubernetes that partition cluster resources between multiple users or teams. They provide an isolated environment, making it easier to manage permissions, limit resource consumption, and enhance security.

### Difference Between RoleBindings and ClusterRoleBindings

- **RoleBinding**: Applies a Role or ClusterRole within the scope of a specific namespace. Even if a ClusterRole is referenced in a RoleBinding, it only grants the permissions defined in that ClusterRole within the namespace where the RoleBinding is created.

- **ClusterRoleBinding**: Applies a ClusterRole across the entire cluster. This means the permissions granted by the ClusterRole are effective in all namespaces, as well as on cluster-scoped resources.

A typical usage will be "Kind: Role" + RoleBinding or "Kind:ClusterRole" + RoleBinding and "Kind:ClusterRole" + "ClusterRoleBinding"

Use "Kind:ClusterRole" + RoleBinding is usually for Reusability and Policy Management. 

- **Reusability**: ClusterRoles can be more flexible if there is any anticipation that the same set of permissions might need to be applied to multiple namespaces in the future. With a ClusterRole, you only need to create additional RoleBindings in other namespaces without duplicating the role definition.

- **Policy Management**: In larger organizations, using ClusterRoles can simplify management by centralizing role definitions. This allows for consistent policy enforcement across multiple namespaces by binding the ClusterRole in different namespaces as needed.

The common use case for ClusterRole+RoleBinding usually uses the least privilege principle. the ClusterRole with least permission can be uniformly applied across many namespaces. 

### Task 1 - Create a ClusterRole for cFOS to be able read configMaps

cFOS PODs require permission to read Kubernetes resources such as configMaps for configurations like IPSEC configuration, Firewall VIP, Policy config, etc., and secrets for cFOS license.

#### Define Rule for Role

A Rule should define the least permission on an API resource:
- **resources**: List of Kubernetes API resources, such as configmaps.
- **apiGroups**: Lists which include the API group to which the resource belongs.
- **verbs**: The permissions on resources.

```
rules:
- apiGroups:
  - ""
  resources:
  - configmaps
  verbs:
  - get
  - list
  - watch
```

`""` indicates the API group is the "CORE" API group. Use `kubectl api-resources | grep configmap` to get the API group for that resource. The output "V1" without a leading group string means it is an empty group, i.e., a CORE API group or legacy API group.

#### Decide to Use ClusterRole or Role

The choice between ClusterRoles and Roles is not always straightforward and can depend on several factors, including management preferences, security requirements, and operational convenience. Using ClusterRoles with RoleBindings is particularly useful for maintaining standard permissions across a cluster while still allowing for namespace-specific customization and security controls. However, if each namespace truly has unique requirements and there is minimal overlap in permissions, your approach of using namespace-specific Roles is optimal and adheres closely to the principle of least privilege.

for cFOS, we can choose either use ClusterRole or Role, as cFOS only require very minimal permission. 

```
kind: ClusterRole
```

#### Complete YAML File for a Role

- use kubectl command  
```bash
kubectl create clusterrole configmap-reader --verb=get,list,watch --resource=configmaps
```
use `kubectl get clusterrole configmap-reader -o yaml` to check the yaml version.

- use yaml file 
```bash
cat << EOF | tee cfosClusterRole1.yaml

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: configmap-reader
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "watch", "list"]

EOF

```
The ClusterRole itself is also a Kubernetes API resource which has an API group "rbac.authorization.k8s.io/v1".


#### Deploy ClusterRole

```bash
kubectl create -f cfosClusterRole1.yaml
```
#### Check Result
- check resource creation result
```bash
kubectl get clusterrole configmap-reader
```
expected Result
```
NAME               CREATED AT
configmap-reader   2024-05-05T08:11:35Z
```
- check resource detail

```bash
kubectl describe clusterrole configmap-reader
```
expected Result
```
Name:         configmap-reader
Labels:       <none>
Annotations:  <none>
PolicyRule:
  Resources   Non-Resource URLs  Resource Names  Verbs
  ---------   -----------------  --------------  -----
  configmaps  []                 []              [get list watch]
```
the empty list [] means the configmaps can read any configmaps. 


### Task 2 - Create a Role for cFOS to be able read secret.

cFOS POD require use imagePullSecret to pull container from image repository.  the imagePullSecret is a "secret" resource in k8s. a "role" or "ClusterRole" is required to read the "secret"

#### Create a ClusterRole for cFOS to read secrets

- use kubectl command
```bash
kubectl create clusterrole secrets-reader --verb=get,list,watch --resource=secrets --resource-name=cfosimagepullsecret,someothername
``` 
- use yaml file 

```bash
cat << EOF | tee cfosClusterRole2.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
   name: secrets-reader
rules:
- apiGroups: [""] # "" indicates the core API group
  resources: ["secrets"]
  resourceNames: ["cfosimagepullsecret","someothername"]
  verbs: ["get", "watch", "list"]
EOF
```
the API groups for resource "secrets" is also CORE group which represented with empty string "".
since read "secrets" could cause security issue, we can further narrow down cFOS can only read "secret" with name "cfosimagepullsecret" or "someothername". 

#### Apply the yaml file

```bash
kubectl create -f cfosClusterRole2.yaml
```


#### Check result

```bash
kubectl describe clusterrole secrets-reader
```

expected result

```
Name:         secrets-reader
Labels:       <none>
Annotations:  <none>
PolicyRule:
  Resources  Non-Resource URLs  Resource Names         Verbs
  ---------  -----------------  --------------         -----
  secrets    []                 [cfosimagepullsecret]  [get watch list]
  secrets    []                 [someothername]        [get watch list]
```



### RoleBinding 


ClusterRole and Role can be bind to a ServiceAccount in namepsace with RoleBinding.  in K8S, a POD will use ServiceAccount to authenticate /authorizationa Pod requires a service account primarily for authentication and authorization purposes when interacting with the Kubernetes API server. the ServiceAccount will be bind to a Role/ClusterRole to get the required permission, container from that POD will have the permission to interact with the Kubernetes API server to use resources such as configmaps or secrets.


#### Create ServiceAccount
ServiceAccount is namespaced resource, if no namespace supplied, it will use "default" namespace

- use kubectl command

```bash
kubectl create namespace cfostest
kubectl create serviceaccount cfos-serviceaccount-$USER -n cfostest
```
you can optionaly add an imagePullSecret to this serviceaccount. so a POD use this serviceaccount can use imagePullSecret to pull container image
```bash
kubectl patch serviceaccount cfos-serviceaccount-$USER -n cfostest \
  -p '{"imagePullSecrets": [{"name": "cfosimagepullsecret"}]}'
```
- use yaml file
```
cat << EOF | tee cfos-serviceaccount-$USER.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cfos-serviceaccount
  namespace: cfostest 
imagePullSecrets:
- name: cfosimagepullsecret
EOF
kubectl create -f cfos-serviceaccount-$USER.yaml 
```

#### Check Result
```bash
kubectl describe sa cfos-serviceaccount-$USER -n cfostest
```
expected Result:
```
Name:                cfos-serviceaccount-i
Namespace:           cfostest
Labels:              <none>
Annotations:         <none>
Image pull secrets:  cfosimagepullsecret
Mountable secrets:   <none>
Tokens:              <none>
Events:              <none>
```
#### Bind ClusterRole to ServiceAccount

Bind previous created ClusterRole "configmap-reader" and "secrets-reader" to serviceaccount in namespace cfostest

- use kubectl command

```bash
kubectl create rolebinding  cfosrolebinding --clusterrole=configmap-reader --serviceaccount=cfostest:serviceaccount-$USER
kubectl create rolebinding  cfosrolebinding --clusterrole=secrets-reader --serviceaccount=cfostest:serviceaccount-$USER
```

- use yaml file

```bash
cat << EOF | tee cfosrolebinding-$USER.yaml
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: cfosrolebinding-configmap-reader-$USER
  namespace: cfostest
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: configmap-reader
subjects:
- kind: ServiceAccount
  name: cfos-serviceaccount-$USER
  namespace: cfostest
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: cfosrolebinding-secrets-reader-$USER
  namespace: cfostest
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: secrets-reader
subjects:
- kind: ServiceAccount
  name: cfos-serviceaccount-$USER
  namespace: cfostest
EOF
kubectl create -f cfosrolebinding-$USER.yaml
```

above RoleBinding bind "ClusterRole" with name "configmap-reader" and "secrets-reader" to subjects "ServiceAccount" in namespace cfostest.

#### Check the result

```bash
kubectl describe rolebinding cfosrolebinding-configmap-reader-$USER -n cfostest 
kubectl describe rolebinding cfosrolebinding-secrets-reader-$USER -n cfostest 
```

#### Check service account permssion
to check a serviceaccount whether has required permission in a namespce. you can use `kubectl auth can-i`

```bash
kubectl auth can-i get configmaps --as=system:serviceaccount:cfostest:cfos-serviceaccount-i -n cfostest
kubectl auth can-i get secretes-reader --as=system:serviceaccount:cfostest:cfos-serviceaccount-i -n cfostest
``` 
above both command shall return "yes" 

#### Create cFOS Deployment and use this serviceaccount

- use kubectl with yaml file 
```bash
cat << EOF | tee cfosPOD.yaml 
---
apiVersion: v1
kind: Pod
metadata:
  name: cfos-pod
spec:
  serviceAccountName: cfos-serviceaccount-i
  containers:
    - name: cfos-container
      image: interbeing/fos:latest
      securityContext:
        capabilities:
          add:
            - NET_ADMIN
            - NET_RAW
            - SYS_ADMIN
      volumeMounts:
      - mountPath: /data
        name: data-volume
  volumes:
  - name: data-volume
    emptyDir: {}
EOF
kubectl apply -f cfosPOD.yaml -n cfostest
```

after deployment. you can use 

```bash
kubectl describe po/cfos-pod -n cfostest  | grep 'Service Account:'
```
expected result 
```
Service Account:  cfos-serviceaccount-i
```
