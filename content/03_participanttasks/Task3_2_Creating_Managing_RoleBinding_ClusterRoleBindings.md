---
title: "Deep Dive into RoleBindings and ClusterRoleBindings"
chapter: false
menuTitle: "Creating and Managing RoleBindings and ClusterRoleBindings"
weight: 2
---

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

#### Chcekc service account with kubectl pod

```bash
apiVersion: v1
kind: Pod
metadata:
  name: kubectl
  labels: 
    app: kubectl
spec:
  serviceAccountName: cfos-serviceaccount
  containers:
  - name: kubectl
    image: bitnami/kubectl
    command:
    - "sleep"
    - "infinity"
```

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



