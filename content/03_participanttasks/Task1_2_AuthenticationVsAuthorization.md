---
title: "Introduction to Kubernetes Security"
chapter: false
menuTitle: "Authentication vs. Authorization"
weight: 2
---

# Objective

Understand the k8s Authentication vs Authorization 

# Kubernetes Authentication vs. Authorization

Kubernetes security involves two primary processes: Authentication and Authorization. These processes ensure that only verified users can perform actions they are permitted to perform within the cluster.

## Authentication
Authentication in Kubernetes confirms the identity of a user or process. It's about answering "who are you?" Kubernetes supports several authentication methods:
- **Client Certificates**
- **Bearer Tokens**
- **Basic Authentication**
- **External Identity Providers** such as OIDC or LDAP

### Common Use Cases for Authentication
- **Client Certificates**: Used in environments where certificates are managed through a corporate PKI.
- **Bearer Tokens**: Common in automated processes or scripts that interact with the Kubernetes API.
- **OIDC**: Used in organizations with existing identity solutions like Active Directory or Google Accounts for user authentication.

## Authorization
Authorization in Kubernetes determines what authenticated users are allowed to do. It answers "what can you do?" There are several authorization methods in Kubernetes:
- **Role-Based Access Control (RBAC)**
- **Attribute-Based Access Control (ABAC)**
- **Node Authorization**
- **Webhook**

### Common Use Cases for Each Authorization Method

#### RBAC (Role-Based Access Control)
- **Use Case**: The most common authorization method, used to finely tune permissions at a granular level based on the roles assigned to users or groups.
- **Example**: Granting a developer read-only access to Pods in a specific namespace.

#### ABAC (Attribute-Based Access Control)
- **Use Case**: Used in environments requiring complex access control decisions based on attributes of the user, resource, or environment.
- **Example**: Allowing access to a resource based on the department attribute of the user and the sensitivity attribute of the resource.

#### Node Authorization
- **Use Case**: Specific to controlling what actions a Kubernetes node can perform, primarily in secure or multi-tenant environments.
- **Example**: Restricting nodes to only read Secrets and ConfigMaps referenced by the Pods running on them.

#### Webhook
- **Use Case**: Used when integrating Kubernetes with external authorization systems for complex security environments.
- **Example**: Integrating with an external policy engine that evaluates whether a particular action should be allowed based on external data not available within Kubernetes.

## Conclusion

Authentication and authorization are foundational to Kubernetes security, ensuring only authenticated and authorized actions are performed within the cluster. While authentication is about verifying identities, authorization ensures the actions those identities attempt to perform are permitted.

## Task 1 
Investigate your current user permission on k8s 
- who are you
```bash
kubectl config get-users
```
- whick cluster you are talking to 
```bash
kubectl config get-contexts
```
expected to see 
```
CURRENT   NAME                          CLUSTER      AUTHINFO           NAMESPACE
*         kubernetes-admin@kubernetes   kubernetes   kubernetes-admin 
```
- what you can do

for example,
check whether has permission to read configmap in kube-system namespace 
```bash
kubectl auth can-i 'list' 'configmaps' -n kube-system
```

check whether i am allowed to do anything in all namespace 
below cli is essentially asking, "Do I have permission to perform any action on any resource in any namespace?"

```bash
kubectl auth can-i '*' '*' -A
```

- how you authenicate to your cluster
```bash
kubectl config view

```
expected result 
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
user "kubernetes-admin" use certificate and key to authenticate itself to k8s API.
