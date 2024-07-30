---
title: "Task 1 - Understanding Roles and ClusterRoles"
chapter: false
linkTitle: "Roles and ClusterRoles"
weight: 1
---

## Objective

Learn about RBAC Roles and ClusterRoles in Kubernetes.

In the previous chapter, we learned how to use RBAC to grant users permission to access Kubernetes. In this chapter, let's dive into more detail about Roles and ClusterRoles.

### Core Concepts of Kubernetes RBAC:

- Role: 
  A Role is crucial when a Pod needs to access Kubernetes API resources such as ConfigMaps or Secrets within a specific namespace. It defines permissions that are limited to one namespace, enhancing security by restricting access scope.

- ClusterRole: 
  Defines rules that represent a set of permissions across the entire cluster. It can also be used to grant access to non-namespaced resources like nodes.

- RoleBinding: 
  Grants the permissions defined in a Role to a user or set of users within a specific namespace.

- ClusterRoleBinding: 
  Grants the permissions defined in a ClusterRole to a user or set of users cluster-wide.

- Rules: 
  Both Roles and ClusterRoles contain rules that define a set of permissions. A rule specifies a set of actions (verbs) that can be performed on a group of resources. Verbs include actions like get, watch, create, delete, etc., and resources might be pods, services, etc.

- Subjects: 
  These are users, groups, or service accounts that are granted access based on their role.

- API Groups:
  Kubernetes organizes APIs into groups to streamline extensions and upgrades, categorizing resources to help manage the API's evolution. Within these groups, verbs define permissible actions on the resources. These verbs are specified in Roles and ClusterRoles to grant precise control over resource access and manipulation.

- Service Account: 
  Service Accounts are used by Pods to authenticate against the Kubernetes API, ensuring that API calls are securely identified and appropriately authorized based on the assigned roles and permissions.

#### Pre-defined RBAC Default Roles

Kubernetes comes with some default RBAC roles and clusterroles which are required for bootstrapping the cluster. For example, the role "system:controller:bootstrap-signer" grants the permission to Kubernetes nodes to bootstrap themselves. It automatically approves and signs certain CSRs used for node bootstrapping. 


- pre-defined role **system:controller:bootstrap-signer**

this role is namespaced. it only grant permission to resource in namespace kube-system
{{< tabs title="roles" >}}
{{% tab title="Get" %}}
```bash
kubectl get role system:controller:bootstrap-signer -n kube-system -o yaml
```
{{% /tab %}}
{{% tab title="Expected Output" style="info" %}}

```yaml
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
{{% /tab %}}
{{< /tabs >}}

To see which RoleBindings are associated with this role:
```bash
kubectl get rolebinding -n kube-system system:controller:bootstrap-signer -o yaml
```
- pre-definded **Clusterrole** 

Another example is the cluster-admin ClusterRole, which grants full administrative privileges across the entire cluster. This role allows nearly unrestricted access to all resources in the cluster, making it suitable for highly privileged users who need to manage and configure any aspect of the cluster. 

this clusterrole is cluster wide. it can apply to entire cluster with clusterrolebinding. 

{{< tabs title="rolebinding" >}}
{{% tab title="Get" %}}
```bash
kubectl get clusterrole cluster-admin -o yaml
```
{{% /tab %}}
{{% tab title="Expected Output1" style="info" %}}
```yaml
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
{{% /tab %}}
{{% tab title="cluster-admin" %}}

The clusterrole "cluster-admin" is bound to the group "system:masters" cluster-wide, providing all permissions to all resources in the cluster.

```bash
kubectl get clusterrolebinding cluster-admin -o yaml
```
{{% /tab %}}
{{% tab title="Expected Output2" style="info" %}}
You can find Clusterrole "cluster-admin" bound to subject user group -"system:masters" with clusterrolebinding
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  creationTimestamp: "2024-05-13T00:00:45Z"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: cluster-admin
  resourceVersion: "136"
  uid: f5753f58-e17c-4ca6-9ff0-cd39eda5f654
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: Group
  name: system:masters

```
{{% /tab %}}
{{< /tabs >}}

### Task:  List all RBAC Default Roles and ClusterRoles

Take a look at what are the default role and clusterole pre-defined for a default cluster.

default role/clusterrole come with a label "kubernetes.io/bootstrapping=rbac-defaults". you can use this label to filter the default role/clusterrole.

- List all default ClusterRoles:

```bash
kubectl get clusterrole -l kubernetes.io/bootstrapping=rbac-defaults
```
- List all default Roles:

```bash
kubectl get role -l kubernetes.io/bootstrapping=rbac-defaults -A
```


