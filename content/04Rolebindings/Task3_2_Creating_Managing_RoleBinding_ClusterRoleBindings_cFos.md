---
title: "Task 2 - Creating and managing RoleBindings and ClusterRoleBindings"
chapter: false
linkTitle: "Creating RoleBindings,ClusterRoleBindings"
weight: 5
---

## Object

Create and Manage RoleBinding and ClusterRoleBinding 

## Create ServiceAccount

K8s cluster internal application like cFOS will use serviceAccount with a JWT token to talk to k8s API. the Role or ClusterRole is bound to serviceAccount which in turn assocated with cFOS Pod.

ServiceAccounts are namespaced resources; if no namespace is supplied, they default to the "default" namespace.

### Task 1: Create a serviceAccount for cFOS and bind to ClusterRole
{{< tabs title="serviceAccount" >}}
{{% tab title="create" %}}
- use kubectl  create cli
```bash
kubectl create namespace cfostest
kubectl create serviceaccount cfos-serviceaccount -n cfostest 
kubectl create clusterrole configmap-reader --verb=get,list,watch --resource=configmaps 
kubectl create clusterrole secrets-reader --verb=get,list,watch --resource=secrets 
```
{{% /tab %}}
{{% tab title="add secret" %}}
Add an imagePullSecret to this service account so a POD using this service account also include a image pull secret to pull container images:

```bash
cd $HOME
kubectl apply -f cfosimagepullsecret.yaml -n cfostest
kubectl get sa -n cfostest 
```

{{% /tab %}}
{{% tab title="patch serviceaccount" %}}
Patch serviceaccount with imagePullSecrets

{{< tabs >}}
{{% tab title="kubectl method" %}}
```bash
kubectl patch serviceaccount cfos-serviceaccount -n cfostest \
  -p '{"imagePullSecrets": [{"name": "cfosimagepullsecret"}]}'
```
{{% /tab %}}
{{% tab title="YAML manifest method" %}}
Or use YAML manifest 

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
{{% /tab %}}
{{< /tabs >}}

{{% /tab %}}


{{% tab title="Check Result" %}}

```bash
kubectl describe sa cfos-serviceaccount -n cfostest
```
{{% /tab %}}
{{% tab title="Expected Result" style="info" %}}
Expected Result:
```tableGen
Name:                cfos-serviceaccount
Namespace:           cfostest
Labels:              <none>
Annotations:         <none>
Image pull secrets:  cfosimagepullsecret
Mountable secrets:   <none>
Tokens:              <none>
Events:              <none>
```
{{% /tab %}}
{{< /tabs >}}

#### Bind ClusterRole to ServiceAccount

Bind previously created ClusterRoles "configmap-reader" and "secrets-reader" to the service account in the namespace cfostest.

{{< tabs >}}

{{% tab title="create clusterRole" %}}
One one of these methods to create a clusterRole

{{< tabs >}}
{{% tab title="kubectl method" %}}
Choose kubectl create cli

```bash
kubectl create rolebinding cfosrolebinding-configmap-reader --clusterrole=configmap-reader --serviceaccount=cfostest:cfos-serviceaccount -n cfostest
kubectl create rolebinding cfosrolebinding-secrets-reader --clusterrole=secrets-reader --serviceaccount=cfostest:cfos-serviceaccount -n cfostest
```
{{% /tab %}}
{{% tab title="Yaml method" %}}
Or use yaml manifest 

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
EOF
kubectl create -f cfosrolebinding.yaml -n cfostest
```
{{% /tab %}}
{{< /tabs >}}

{{% /tab %}}
{{% tab title="Check result" %}}

```bash
kubectl describe rolebinding cfosrolebinding-configmap-reader -n cfostest
kubectl describe rolebinding cfosrolebinding-secrets-reader -n cfostest
```
{{% /tab %}}
{{% tab title="Expected Output" %}}
```tableGen
Name:         cfosrolebinding-configmap-reader
Labels:       <none>
Annotations:  <none>
Role:
  Kind:  ClusterRole
  Name:  configmap-reader
Subjects:
  Kind            Name                 Namespace
  ----            ----                 ---------
  ServiceAccount  cfos-serviceaccount  cfostest
Name:         cfosrolebinding-secrets-reader
Labels:       <none>
Annotations:  <none>
Role:
  Kind:  ClusterRole
  Name:  secrets-reader
Subjects:
  Kind            Name                 Namespace
  ----            ----                 ---------
  ServiceAccount  cfos-serviceaccount  cfostest
```
{{% /tab %}}
{{< /tabs >}}

### Check service account permission

Use `kubectl auth can-i` to check if a service account has the required permissions in a namespace.

```bash
kubectl auth can-i get configmaps --as=system:serviceaccount:cfostest:cfos-serviceaccount -n cfostest
kubectl auth can-i get secrets --as=system:serviceaccount:cfostest:cfos-serviceaccount -n cfostest
```
Both commands should return "yes".

### Check service account with kubectl pod
{{< tabs title="Apply Service Account" >}}
{{% tab title="apply" %}}
```bash
cat << EOF | kubectl -n cfostest apply -f - 
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
{{% /tab %}}
{{% tab title="Check Result" %}}

```bash
kubectl exec -it po/kubectl -n cfostest  -- kubectl get cm
kubectl exec -it po/kubectl -n cfostest  -- kubectl get secret
```

{{% /tab %}}
{{% tab title="Expected Output" %}}
both command show able to list cm and secret in namespace cfostest 
```tableGen
NAME               DATA   AGE
kube-root-ca.crt   1      3m32s
NAME                  TYPE                             DATA   AGE
cfosimagepullsecret   kubernetes.io/dockerconfigjson   1      3m25s
```
{{% /tab %}}
{{< /tabs >}}

### Task 2 - Create cFOS Deployment and with serviceaccount

- Using kubectl with a YAML file 

{{< tabs title="cFOS Deployment" >}}
{{% tab title="kubectl" %}}
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
      image: $cfosimage
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
{{% /tab %}}
{{% tab title="Verify" %}}
After deployment, you can use:

```bash
kubectl describe po/cfos-pod -n cfostest | grep 'Service Account:'
```
{{% /tab %}}
{{% tab title="Expected result" %}}

```
Service Account: cfos-serviceaccount
```

{{% /tab %}}
{{< /tabs >}}

### clean up

```bash
kubectl delete namespace cfostest
kubectl delete clusterrole configmap-reader
kubectl delete clusterrole secrets-reader
```
