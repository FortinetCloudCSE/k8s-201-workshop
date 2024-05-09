---
title: "Managing Role-Based Access Control (RBAC)"
chapter: false
menuTitle: "Understanding Roles and ClusterRoles"
weight: 2
---

## Objective

Learn What is RBAC and Core Concepts

### What is K8S RBAC

"Kubernetes RBAC (Role-Based Access Control) is an authorization mechanism that regulates interactions with resources within a cluster. It operates by defining roles with specific permissions and binding these roles to users or service accounts. This approach ensures that only authorized entities can perform actions on resources such as pods, deployments, or secrets. By adhering to the principle of least privilege, RBAC allows each user or application access only to the permissions necessary for their tasks. It's important to note that RBAC deals exclusively with authorization and not with authentication; it assumes that the identity of users or service accounts has been verified prior to enforcing access controls."


### Core Concepts of Kubernetes RBAC:

- **Role**: 
  A Role is crucial when a Pod needs to access Kubernetes API resources such as ConfigMaps or Secrets within a specific namespace. It defines permissions that are limited to one namespace, enhancing security by restricting access scope.
- **ClusterRole**: Defines rules that represent a set of permissions across the entire cluster. It can also be used to grant access to non-namespaced resources like nodes.

- **RoleBinding**: Grants the permissions defined in a Role to a user or set of users within a specific namespace.
- **ClusterRoleBinding**: Grants the permissions defined in a ClusterRole to a user or set of users cluster-wide.

- **Rules**: Both Roles and ClusterRoles contain rules that define a set of permissions. A rule specifies a set of actions (verbs) that can be performed on a group of resources. Verbs include actions like get, watch, create, delete, etc., and resources might be pods, services, etc.
- **Subjects**: These are users, groups, or service accounts that are granted access based on their role. 

- **API Groups**:
  Kubernetes organizes APIs into groups to streamline extensions and upgrades, categorizing resources to help manage the API's evolution. API groups allow users to extend the Kubernetes API with their own resources logically. Within these groups, verbs define permissible actions on the resources. Verbs such as `get`, `list`, `watch`, `create`, `update`, and `delete` define what operations are permitted on the resources managed through the API. These verbs are specified in Roles and ClusterRoles to grant precise control over how resources are accessed and manipulated, ensuring that permissions are exactly aligned with user or application requirements.

- **Service Account**: 
  Service Accounts are used by Pods to authenticate against the Kubernetes API, ensuring that API calls are securely identified and appropriately authorized based on the assigned roles and permissions.

#### Pre-definded RBAC default-role
k8s come with some default RBAC role and clusterrole  which are required for bootstrap the k8s. for example. role "system:controller:bootstrap-signer" grant the permission to k8s node to bootstrap itself which automatically approves and signs certain CSRs that are used for node bootstrapping,another example is *cluster-admin* ClusterRole, in Kubernetes is one of the most powerful built-in roles and is used to grant full administrative privileges across the entire cluster. This role allows nearly unrestricted access to all resources in the cluster, making it suitable for highly privileged users who need to manage and configure any aspect of the cluster.  
```bash
kubectl get role system:controller:bootstrap-signer  -n kube-system -o yaml
```
expected output

```
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  creationTimestamp: "2024-03-22T05:51:03Z"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:controller:bootstrap-signer
  namespace: kube-system
  resourceVersion: "179"
  uid: b8180d72-f23d-4950-acb4-2c7a51cdb961
rules:
- apiGroups:
  - ""
  resources:
  - secrets
  verbs:
  - get
  - list
  - watch
```
use `kubectl get rolebinding -n kube-system  system:controller:bootstrap-signer -o yaml` can find this role is bind to serviceaccount bootstrap-signer in kube-system namespace 
this means service account "bootstrap-signer" has permission to [get,list,watch] secrets in namepsace kube-system via default API group ("")  which is CORE API group. 

```bash
kubectl get clusterrole cluster-admin -o yaml
```
expected output
```
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  creationTimestamp: "2024-03-22T05:51:03Z"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: cluster-admin
  resourceVersion: "135"
  uid: 471a5843-4f14-4cbb-ac61-02afb2a701fd
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: Group
  name: system:masters
```
above can found the clusterrole "cluster-admin" bind to group "system:masters" cluster wide. 
use `kubectl get clusterrole cluster-admin -o yaml` can find it has all permission to all resource in cluster.

"kubectl is a key example of a tool that uses the cluster-admin ClusterRole. When kubectl issues a command, such as kubectl create deployment, and once it's authenticated with the supplied certificate, Kubernetes can determine that the user belongs to the system:masters group based on the certificate information. Then, RBAC grants the permissions defined in the cluster-admin role for all operations. Kubernetes itself does not manage users and user groups internally; the group name system:masters is essentially just a label used within Kubernetes RBAC configurations."



### list all rbac-default role and clusterrole

- role

```bash
kubectl get clusterrole -l kubernetes.io/bootstrapping=rbac-defaults 
```
- clusterrole 
```bash
kubectl get role -l kubernetes.io/bootstrapping=rbac-defaults  -A
```

