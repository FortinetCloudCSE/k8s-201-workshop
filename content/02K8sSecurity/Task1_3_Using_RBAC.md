---
title: "Introduction to Kubernetes Security"
chapter: false
linkTitle: "Using RBAC"
weight: 10
---

## Objective

Learn how to use RBAC to control access to the Kubernetes Cluster.

## What is RBAC 

Kubernetes RBAC (Role-Based Access Control) is an authorization mechanism that regulates interactions with resources within a cluster. It operates by defining roles with specific permissions and binding these roles to users or service accounts. This approach ensures that only authorized entities can perform actions on resources such as pods, deployments, or secrets. By adhering to the principle of least privilege, RBAC allows each user or application access only to the permissions necessary for their tasks. It's important to note that RBAC deals exclusively with authorization and not with authentication; it assumes that the identity of users or service accounts has been verified prior to enforcing access controls.


![RBAC](https://snyk.io/_next/image/?url=https%3A%2F%2Fres.cloudinary.com%2Fsnyk%2Fimage%2Fupload%2Ff_auto%2Fq_auto%2Fv1618003343%2Fwordpress-sync%2Fblog-k8s-rbac-diagram.png&w=2560&q=75 "RBAC")

Below let's walk through how to define a role with limited permission and apply to an user for access Kubernetes Cluster

## Task 1: Create Read-Only User for Access Cluster

Create a New User Account for Developers to Access the Kubernetes Cluster, the user only has read-only permission


### Create a Certificate for the User

- Generate a Certificate Signing Request (CSR):
{{< tabs title="CSR" >}}
{{% tab title="generate" %}}
Kubernetes uses the group "system:authenticated" as a predefined label, which is trusted by external clients to dictate group membership. Kubernetes itself does not validate which group a user belongs to. This step involves generating a private key and a CSR using OpenSSL.

```bash
openssl genrsa -out newuser.key 2048
openssl req -new -key newuser.key -out newuser.csr -subj "/CN=tecworkshop/O=Devops"
```
{{% /tab %}}
{{% tab title="Prepare CSR" %}}

Create a YAML file for the CSR object in Kubernetes. This object includes the base64-encoded CSR data.

```bash
cat << EOF | tee csrfortecworkshop.yaml
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: tecworkshop
spec:
  groups:
    - system:authenticated
  request: $(cat newuser.csr | base64 | tr -d "\n")
  signerName: kubernetes.io/kube-apiserver-client
  usages:
    - client auth
EOF
kubectl create -f csrfortecworkshop.yaml
```
{{% /tab %}}
{{% tab title="Check CSR" %}}
Initially, the CSR will be in a pending state.
```bash
  kubectl get csr tecworkshop
```
{{% /tab %}}
{{% tab title="Expected Output" style="info" %}}
You should see **Condition** as **Pending**
```tableGen
NAME          AGE   SIGNERNAME                            REQUESTOR           REQUESTEDDURATION   CONDITION
tecworkshop   18s   kubernetes.io/kube-apiserver-client   kubernetes-admin    <none>              Pending
```
{{% /tab %}}
{{< /tabs >}}

- Approve the CSR:
{{< tabs title="Approve" >}}
{{% tab title="Approve" %}}
Approve the CSR to issue the certificate.
```bash
kubectl certificate approve tecworkshop
```
{{% /tab %}}
{{% tab title="Verify CSR" %}}
Verify the CSR has been approved and issued:
```bash
kubectl get csr tecworkshop
```
{{% /tab %}}
{{% tab title="Expected Output" style="info" %}}
You should see **Condition** as **Approved, Issued**
```tableGen
NAME          AGE   SIGNERNAME                            REQUESTOR           REQUESTEDDURATION   CONDITION
tecworkshop   66s   kubernetes.io/kube-apiserver-client   kubernetes-admin    <none>              Approved,Issued
```
{{% /tab %}}
{{< /tabs >}}

- Save the Certificate to a File:
{{< tabs title="Save Cert" >}}
{{% tab title="Extract & Decode" %}}
Extract and decode the certificate.
```bash
kubectl get csr tecworkshop -o jsonpath='{.status.certificate}' | base64 --decode > newuser.crt
```
{{% /tab %}}
{{% tab title="View Cert" %}}
Optionally, View Certificate Details:
```bash
openssl x509 -in newuser.crt -text -noout
```
{{% /tab %}}
{{% tab title="credentials" %}} 
Set Credentials for the New User:

Configure kubectl to use the new user's credentials.

```bash
kubectl config set-credentials tecworkshop --client-certificate=newuser.crt --client-key=newuser.key
```
{{% /tab %}}
{{% tab title="context setup" %}}
Create a New Context for the New User:

Set up a context that specifies the new user and cluster.

```bash
  adminContext=$(kubectl config current-context)
  adminCluster=$(kubectl config current-context | cut -d '@' -f 2)
  kubectl config set-context tecworkshop-context --cluster=$adminCluster --user=tecworkshop
```
{{% /tab %}}
{{% tab title="context change" %}}
Switch to the New Context:

Use the new context to interact with the cluster as the new user.

```bash
kubectl config use-context tecworkshop-context
```
{{% /tab %}}
{{% tab title="Verify Access" %}}
Attempt to retrieve pods; it should fail due to lack of permissions.

```bash
kubectl get pods
```
{{% /tab %}}
{{% tab title="Expected Output" style="info" %}}
You should see an error:
```tableGen
Error from server (Forbidden): pods is forbidden: User "tecworkshop" cannot list resource "pods" in API group "" in the namespace "default"
```
{{% /tab %}}
{{< /tabs >}}

## Task 2: Authorize the User to List All Pods in All Namespaces

Use RBAC to grant the new user permission to list all pods across all namespaces.

{{< tabs title="RBAC" >}}
{{% tab title="Admin Context" %}}
- Switch to an Admin Context:

You need sufficient permissions to create roles and role bindings.

```bash
kubectl config use-context $adminContext
```
{{% /tab %}}
{{% tab title="ClusterRole create" %}}

- Define a ClusterRole:

Create a `ClusterRole` that allows reading pods across all namespaces.

```bash
kubectl create clusterrole readpods --verb=get,list,watch --resource=pods
```
{{% /tab %}}
{{% tab title="clusterRole bind" %}}

- Bind the ClusterRole to the New User:

Create a `ClusterRoleBinding` to assign the role to the new user.

```bash
kubectl create clusterrolebinding readpodsbinding --clusterrole=readpods --user=tecworkshop
```
{{% /tab %}}
{{% tab title="User Context" %}}

- Switch Back to the New User Context:

```bash
kubectl config use-context tecworkshop-context
```
{{% /tab %}}
{{% tab title="Verify permissions" %}}

- Verify Permissions:

Now, the new user should be able to list pods in all namespaces.

```bash
kubectl get pod -A
```

Or, check specific permissions:

```bash
kubectl auth can-i get pods -A
```
{{% /tab %}}
{{% tab title="Expected Output" style="info" %}}
You should be able to view all pods and have **yes** to specific permissions
```
yes
```
{{% /tab %}}
{{< /tabs >}}

### Switch back to admin user

make sure switch back to admin user for full control the k8s cluster

```bash
kubectl config use-context $adminContext
```
### Summary


Above, we have detailed the process for granting human users the least privilege necessary to access the Kubernetes cluster. In the next chapter, we will explore how to restrict a POD or container by using a service account with the least privilege necessary for accessing the cluster.

This ensures that not only are human users operating under the principle of least privilege, but automated processes and applications within your cluster are also adhering to strict access controls, enhancing the overall security posture of your Kubernetes environment.



### Clean up 

```bash
kubectl config use-context $adminContext
kubectl config delete-context tecworkshop-context
kubectl config delete-user tecworkshop
```
