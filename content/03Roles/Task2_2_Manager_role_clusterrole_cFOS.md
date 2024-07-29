---
title: "Task 2 - Creating and Managing Roles and ClusterRoles for cFOS"
chapter: false
menuTitle: "Roles and ClusterRoles for cFOS"
weight: 5
---

## Objective

Create Roles and ClusterRoles for the cFOS application.

### Core Concepts

- Role for ConfigMaps: cFOS needs to interact with the Kubernetes API to read ConfigMaps for configurations such as IPSEC, Firewall VIP, Policy config, and License.
- Role for Secrets: cFOS needs to interact with the Kubernetes API to read secrets, such as those used for pulling images,ipsec shared key etc.,

### Create a ClusterRole for cFOS to Read ConfigMaps

cFOS pods require permission to read Kubernetes resources such as ConfigMaps. This includes permissions to watch, list, and read the ConfigMaps.

#### Define Rule for Role

A rule should define the least permission on an API resource:
- resources: List of Kubernetes API resources, such as configmaps.
- apiGroups: Lists which include the API group to which the resource belongs.
- verbs: The permissions on resources.

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

{{% notice style="info" %}}
`""` indicates the API group is the "CORE" API group.
{{% /notice %}}

#### Decide to Use ClusterRole or Role

For cFOS, either a ClusterRole or a Role can be used as cFOS only requires minimal permissions. 

```
kind: ClusterRole
```

### Task 1 - Create a clusterrole for cFOS 

you can use kubectl create command or use a yaml file.

{{% tabs title="c" %}}
```c
printf("Hello World!");
```
{{% /tabs %}}

- Using kubectl command:

```bash
kubectl create clusterrole configmap-reader --verb=get,list,watch --resource=configmaps 
```

- Using a YAML file:

```bash
cat << EOF | tee cfosConfigMapsClusterRole.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: configmap-reader
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "watch", "list"]
EOF
kubectl create -f cfosConfigMapsClusterRole.yaml 
```

- Check Result


```bash
kubectl get clusterrole configmap-reader
```
Expected Result:
```
NAME               CREATED AT
configmap-reader   2024-05-05T08:11:35Z
```

- Check resource detail:

```bash
kubectl describe clusterrole configmap-reader
```
Expected Result:
```
Name:         configmap-reader
Labels:       <none>
Annotations:  <none>
PolicyRule:
  Resources   Non-Resource URLs  Resource Names  Verbs
  ---------   -----------------  --------------  -----
  configmaps  []                 []              [get list watch]
```
The empty list [] under "Non-Resource URLs" and "Resource Names" means the configmaps can read any configmaps.

### Task 2 - Create a Role for cFOS to Read Secrets

cFOS pods require using imagePullSecret to pull containers from an image repository. A "role" or "ClusterRole" is required to read the "secret."

#### Create a ClusterRole for cFOS to Read Secrets

- Using kubectl command:
```bash
kubectl create clusterrole secrets-reader --verb=get,list,watch --resource=secrets --resource-name=cfosimagepullsecret,someothername
```
{{% notice style="info" %}}
--resource-name is optional, only needed if you want clusterrole only able to read the secret with specific resource name. 
{{% /notice %}}

- Using a YAML file:

```bash
cat << EOF | tee cfosSecretClusterRole.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
   name: secrets-reader
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["cfosimagepullsecret","someothername"]
  verbs: ["get", "watch", "list"]
EOF
kubectl create -f cfosSecretClusterRole.yaml
```

#### Check Result

```bash
kubectl describe clusterrole secrets-reader
```
Expected Result:
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

### Summary

We defined two ClusterRoles for cFOS in this chapter. In the next chapter, we will explore how to bind these ClusterRoles to the serviceAccount of cFOS.

### Clean up

```bash
kubectl delete clusterrole configmap-reader
kubectl delete clusterrole secrets-reader
```

