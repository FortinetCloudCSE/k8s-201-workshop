---
title: "Introduction to Kubernetes Security"
chapter: false
menuTitle: "Using RBAC for Secure Access"
weight: 2
---

# Objective


## Task 1 Create a new user  accoutn for developer to use kubernetes cluster

Create a read-only user account for other user to use your cluster

### Create a certificate for User
- Create a CSR 

the groups: "system:authenticated" is the pre-defined group name in k8s. k8s does not store user information internally also  do not validate user belong to which group. it's just trust the external client telling the user belong to which group. group name is just predefined labels which will be used to find the related role/permission

```bash
openssl genrsa -out newuser.key 2048
openssl req -new -key newuser.key -out newuser.csr -subj "/CN=tecworkshop/O=Devops"
cat <<EOF | tee csrfortecworkshop.yaml
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
- Check Result
```bash
kubectl get csr tecworkshop
```
Expected to got
```
NAME          AGE   SIGNERNAME                            REQUESTOR          REQUESTEDDURATION   CONDITION
tecworkshop   18s   kubernetes.io/kube-apiserver-client   kubernetes-admin   <none>              Pending
```
- Sign CSR 
```bash
kubectl certificate approve tecworkshop
```
- Check Result agin
```bash
kubectl get csr tecworkshop
```
expect to get 
```
NAME          AGE   SIGNERNAME                            REQUESTOR          REQUESTEDDURATION   CONDITION
tecworkshop   66s   kubernetes.io/kube-apiserver-client   kubernetes-admin   <none>              Approved,Issued
```
- save the certificate to a file
```bash
kubectl get csr tecworkshop -o jsonpath='{.status.certificate}' | base64 -d >> newuser.crt
```
optionaly, you can see certificate detail by use below command.
```bash
openssl x509 -in newuser.crt -text -noout
```
- set credentails for newuser
the credentails will be used in kubeconfig file to interact with kubernetes API server
```bash
kubectl config set-credentials tecworkshop --client-certificate=newuser.crt --client-key=newuser.key
```
- create new context for newuser 
```bash
kubectl config set-context tecworkshop-context --cluster=kubernetes --user=tecworkshop
```
- use new context
```bash
kubectl config use-context tecworkshop-context
```
- verify
```bash
k auth can-i get pods
```
expected to see
```no
```
- try to list pod
```bash
kubectl get pods
```
expected result
```
Error from server (Forbidden): pods is forbidden: User "tecworkshop" cannot list resource "pods" in API group "" in the namespace "default"
```
the user is authenticated, but have not "authorized" with any permission. to "authorize" user with pemission. kubernetes RBAC is the component for this. 

## Task 2 Authorize user  to list all pods in all namespace

RBAC is the recommend way to Authorize user. let's use RBAC to create a role for newuser. to be able to create a role. we have to switch back to use previous context. previous context include admin account which have enough permission to create a role  
```bash
kubectl config use-context kubernetes-admin@kubernetes
```

- define a Role
RBAC allow you to define a role which only valid in specific namespace or a clusterrole which work for all namespaces with clusterbinding. if we can list all pods in all namespace, the role will require be "clusterrole" and also require use "clusterrolebinding" 

```
kubectl create clusterrole readpods --verb=get,list,watch --resource=pods
``` 

expected result
```
clusterrole.rbac.authorization.k8s.io/readpods created
```

- bind to ClusterRole to User with clusterrolebinding
```bash
kubectl create clusterrolebinding readpodsbinding --clusterrole=readpods --user=tecworkshop
```
expected result

```
clusterrolebinding.rbac.authorization.k8s.io/readpodsbinding created
```
- choose to use new context
```bash
kubectl config use-context tecworkshop-context
```
- check result

you are expected to list all pods in all namespace and `kubectl auth can-i get pods -A` shall get "yes"
```bash
kubectl get pod -A
```
or 
```bash
kubectl auth can-i get pods -A
```

