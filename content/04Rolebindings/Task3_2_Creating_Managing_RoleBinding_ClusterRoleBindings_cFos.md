---
title: "Task 2 - Creating and managing RoleBindings and ClusterRoleBindings"
chapter: false
menuTitle: "Creating RoleBindings,ClusterRoleBindings"
weight: 5
---

## Create ServiceAccount
ServiceAccounts are namespaced resources; if no namespace is supplied, they default to the "default" namespace.

### Using kubectl command

```bash
kubectl create namespace cfostest
kubectl create serviceaccount cfos-serviceaccount -n cfostest
```

Optionally, add an imagePullSecret to this service account so a POD using this service account can pull container images:

```bash
kubectl patch serviceaccount cfos-serviceaccount -n cfostest \
  -p '{"imagePullSecrets": [{"name": "cfosimagepullsecret"}]}'
```

### Using YAML file

```
cat << EOF | tee cfos-serviceaccount.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cfos-serviceaccount
  namespace: cfostest 
imagePullSecrets:
- name: cfosimagepullsecret
EOF
kubectl create -f cfos-serviceaccount.yaml 
```

### Check Result

```bash
kubectl describe sa cfos-serviceaccount -n cfostest
```
Expected Result:
```
Name:                cfos-serviceaccount
Namespace:           cfostest
Labels:              <none>
Annotations:         <none>
Image pull secrets:  cfosimagepullsecret
Mountable secrets:   <none>
Tokens:              <none>
Events:              <none>
```

### Bind ClusterRole to ServiceAccount

Bind previously created ClusterRoles "configmap-reader" and "secrets-reader" to the service account in the namespace cfostest.

### Using kubectl command

```bash
kubectl create rolebinding cfosrolebinding-configmap --clusterrole=configmap-reader --serviceaccount=cfostest:cfos-serviceaccount
kubectl create rolebinding cfosrolebinding-secrets --clusterrole=secrets-reader --serviceaccount=cfostest:cfos-serviceaccount
```

### Using YAML file

```bash
cat << EOF | tee cfosrolebinding.yaml
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: cfosrolebinding-configmap-reader
  namespace: cfostest
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: configmap-reader
subjects:
- kind: ServiceAccount
  name: cfos-serviceaccount
  namespace: cfostest
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: cfosrolebinding-secrets-reader
  namespace: cfostest
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: secrets-reader
subjects:
- kind: ServiceAccount
  name: cfos-serviceaccount
  namespace: cfostest
EOF
kubectl create -f cfosrolebinding.yaml
```

### Check the result

```bash
kubectl describe rolebinding cfosrolebinding-configmap-reader -n cfostest
kubectl describe rolebinding cfosrolebinding-secrets-reader -n cfostest
```

### Check service account permission

Use `kubectl auth can-i` to check if a service account has the required permissions in a namespace.

```bash
kubectl auth can-i get configmaps --as=system:serviceaccount:cfostest:cfos-serviceaccount -n cfostest
kubectl auth can-i get secrets --as=system:serviceaccount:cfostest:cfos-serviceaccount -n cfostest
```
Both commands should return "yes".

### Check service account with kubectl pod

```yaml
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

### Create cFOS Deployment and use this service account

- Using kubectl with a YAML file 

```bash
cat << EOF | tee cfosPOD.yaml 
---
apiVersion: v1
kind: Pod
metadata:
  name: cfos-pod
spec:
  serviceAccountName: cfos-serviceaccount
  containers:
    - name: cfos-container
      image: interbeing/fos:latest
      securityContext:
        capabilities:
          add:
            - NET_ADMIN
            - NET_RAW
      volumeMounts:
      - mountPath: /data
        name: data-volume
  volumes:
  - name: data-volume
    emptyDir: {}
EOF
kubectl apply -f cfosPOD.yaml -n cfostest
```

After deployment, you can use:

```bash
kubectl describe po/cfos-pod -n cfostest | grep 'Service Account:'
```
Expected result:
```
Service Account: cfos-serviceaccount
```


### Q&A

- How to verify the serviceAccount acutally has required permission to target resource ?

Answer:

Creaet a Pod which has kubectl cli , then bind Pod with serviceAccount
for example , use below yaml 

```
### Check service account with kubectl pod

```
cat << EOF | kubectl apply -n cfostest -f - 
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
EOF

```

after deploy above yaml. then shell into this pod and run

shell into pod

```bash
kubectl exec -it po/kubectl -n cfostest -- sh
```
then 
```bash
kubectl get configmap
```
and 
```bash
kubectl get secret
```
