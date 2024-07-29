---
title: "Authentication, Authorization, and Admission Control"
chapter: false
linkTitle: "AuthenticationvsAuthorization"
weight: 5
---

## Objective

Understand the differences between Kubernetes Authentication, Authorization, and Admission Control.

## Kubernetes Authentication, Authorization, and Admission Control

Kubernetes security involves three primary processes: Authentication, Authorization, and Admission Control. These processes ensure that only verified users can perform actions they are permitted to perform within the cluster, and that those actions are validated by Kubernetes before they are executed.

![3A](https://kubernetes.io/images/docs/admin/access-control-overview.svg "3A image")
## Authentication

Authentication in Kubernetes confirms the identity of a user or process. It's about answering "who are you?" Kubernetes supports several authentication methods:
- Client Certificates
- Bearer Tokens
- Basic Authentication
- External Identity Providers such as OIDC or LDAP

### Common Use Cases for Authentication
- Client Certificates: Used in environments where certificates are managed through a corporate PKI.
- Bearer Tokens: Common in automated processes or scripts that interact with the Kubernetes API.
- OIDC: Used in organizations with existing identity solutions like Active Directory or Google Accounts for user authentication.

## Authorization

Authorization in Kubernetes determines what authenticated users are allowed to do. It answers "what can you do?" There are several authorization methods in Kubernetes:
- **Role-Based Access Control (RBAC)**
- Attribute-Based Access Control (ABAC)
- Node Authorization
- Webhook

### Common Use Cases for Each Authorization Method

#### RBAC (Role-Based Access Control)
- Use Case: The most common authorization method, used to finely tune permissions at a granular level based on the roles assigned to users or groups.
- Example: Granting a developer read-only access to Pods in a specific namespace.

#### ABAC (Attribute-Based Access Control)
- Use Case: Used in environments requiring complex access control decisions based on attributes of the user, resource, or environment.
- Example: Allowing access to a resource based on the department attribute of the user and the sensitivity attribute of the resource.

#### Node Authorization
- Use Case: Specific to controlling what actions a Kubernetes node can perform, primarily in secure or multi-tenant environments.
- Example: Restricting nodes to only read Secrets and ConfigMaps referenced by the Pods running on them.

#### Webhook
- Use Case: Used when integrating Kubernetes with external authorization systems for complex security environments.
- Example: Integrating with an external policy engine that evaluates whether a particular action should be allowed based on external data not available within Kubernetes.

## Admission Control

Admission Control in Kubernetes is a process that intercepts requests to the Kubernetes API before they are persisted to ensure that they meet specific criteria set by the administrator. Admission Controllers are plugins that govern and enforce how the cluster is used.

Admission controllers are not enabled by default. They must be explicitly configured and enabled when starting the Kubernetes API server. The admission control process is specified through the --enable-admission-plugins flag on the API server. 

### Common Admission Controllers

#### Pod Security Policies (PSP)
- Use Case: Ensures that Pods meet security requirements by denying the creation of Pods that do not adhere to defined policies.
- Example: Restricting the use of privileged containers or the host network.

#### ResourceQuota
- Use Case: Enforces limits on the aggregate resource consumption per namespace.
- Example: Preventing any one namespace from using more than a certain amount of CPU or memory resources.

#### LimitRanger
- Use Case: Enforces defaults and limits on the sizes of resources like Pods, containers, and PersistentVolumeClaims.
- Example: Ensuring that every Pod has a memory request and limit to avoid resource exhaustion.

## Summary

Authentication, authorization, and admission control are foundational to Kubernetes security, ensuring only authenticated and authorized actions that meet the cluster's policy requirements are performed within the cluster.

## Task 1 Investigate your k8s environment

- Who are you?
```bash
kubectl config view --minify -o jsonpath='{.users[0].name}'
```

- Which cluster are you connected to?
```bash
kubectl config current-context
```

- What can you do?

For example, check whether you have permission to read configmaps in the kube-system namespace:
```bash
kubectl auth can-i list configmaps -n kube-system
```

Check whether you are allowed to do anything in all namespaces:
```bash
kubectl auth can-i '*' '*' -A
```

- How do you authenticate to your cluster?
```bash
kubectl config view
```

Expected result:

- Self Managed k8s 
```
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: DATA+OMITTED
    server: https://k8strainingmaster1.westus.cloudapp.azure.com:6443
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: kubernetes-admin
  name: kubernetes-admin@kubernetes
current-context: kubernetes-admin@kubernetes
kind: Config
preferences: {}
users:
- name: kubernetes-admin
  user:
    client-certificate-data: DATA+OMITTED
    client-key-data: DATA+OMITTED
```
The user "kubernetes-admin" uses a certificate and key to authenticate itself to the Kubernetes API.

or 
- AKS

```
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: DATA+OMITTED
    server: https://k8s51-aks--k8s51-k8s101-wor-02b500-zf9ekyl6.hcp.eastus.azmk8s.io:443
  name: k8s51-aks-cluster
contexts:
- context:
    cluster: k8s51-aks-cluster
    user: clusterUser_k8s51-k8s101-workshop_k8s51-aks-cluster
  name: k8s51-aks-cluster
current-context: k8s51-aks-cluster
kind: Config
preferences: {}
users:
- name: clusterUser_k8s51-k8s101-workshop_k8s51-aks-cluster
  user:
    client-certificate-data: DATA+OMITTED
    client-key-data: DATA+OMITTED
    token: REDACTED
```
The user "clusterUser_k8s51-k8s101-workshop_k8s51-aks-cluster" uses a certificate and key to authenticate itself to the Kubernetes API.
