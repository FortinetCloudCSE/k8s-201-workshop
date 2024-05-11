---
title: "Managing Role-Based Access Control (RBAC)"
chapter: false
menuTitle: "Creating and Managing Roles and ClusterRoles"
weight: 2
---

## Objective

Create Role and ClusterRoles

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


Summary
