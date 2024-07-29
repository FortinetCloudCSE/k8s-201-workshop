---
title: "Task 3 - Creating and Managing Storage"
chapter: false
linkTitle: "Storage"
weight: 10
---

## Use external data

Application like cFOS may persist the data such as license, configuration data, log etc to storage that outside of the POD. for example, cFOS container will like to mount /data to other Volume.

to do that, we have to create a "Volume" attached to POD for container to mount

1. field spec.template.spec.containers.volmeMounts will try to mount /data directory in cfos to Volume /data-volume
2. field spec.template.spec.volumens define the volume with name "data-volume" and it's actual storage location is on host directory /cfosdata


```bash
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: cfos-deployment
spec:
  selector:
    matchLabels:
      app: cfos
  template:
    metadata:
      labels:
        app: cfos
    spec:
      containers:
      - name: cfos
        image: $cfosimage
        securityContext:
          capabilities:
            add: ["NET_ADMIN", "SYS_ADMIN", "NET_RAW"]
        volumeMounts:
        - mountPath: /data
          name: data-volume
      volumes:
      - name: data-volume
        hostPath:
          path: /cfosdata
          type: DirectoryOrCreate 
```

## the types of volumes 

- PVC (Persistent Volume Claims)

Persistent Volume Claims are a way of letting users consume abstract storage resources, while allowing administrators to manage the provisioning of storage and its underlying details in a flexible manner. PVCs are used in scenarios where persistent storage is needed for stateful applications, such as databases, key-value stores, and file storage.

- emptyDir

An emptyDir volume is created when a Pod is assigned to a Node, and it exists as long as that Pod is running on that Node. The data in an emptyDir volume is deleted when the Pod is removed.

- nfs (Network File System)

An nfs volume allows an existing NFS (Network File System) share to be mounted into a Pod. NFS volumes are often used in environments where data needs to be quickly and easily shared between Pods.

- awsElasticBlockStore, gcePersistentDisk, and azureDisk

These volumes allow you to integrate Kubernetes Pods with cloud provider-specific storage solutions, like AWS EBS, GCE Persistent Disks, and Azure Disk.

- hostPath

A path directly on host node. 

- ###  Example 1 - config cfos deployment to use PVC 

- Create cFos license, imagePullSecret and serviceAccount

```bash
scriptDir=$HOME
kubectl create namespace cfostest
kubectl apply -f cfosimagepullsecret.yaml -n cfostest
kubectl apply -f $scriptDir/k8s-201-workshop/scripts/cfos/Task1_1_create_cfos_serviceaccount.yaml  -n cfostest
```
- create PVC with required capacity

```bash
cat << EOF | kubectl apply -n cfostest -f - 
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: cfosdata
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF
```

- create cfos Deployment with pvc 

```bash
cat << EOF | kubectl apply -n cfostest -f - 
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cfos7210250-deployment
  labels:
    app: cfos
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cfos
  template:
    metadata:
      annotations:
        container.apparmor.security.beta.kubernetes.io/cfos7210250-container: unconfined
      labels:
        app: cfos
    spec:
      serviceAccountName: cfos-serviceaccount
      containers:
      - name: cfos7210250-container
        image: $cfosimage
        securityContext:
          capabilities:
              add: ["NET_ADMIN","SYS_ADMIN","NET_RAW"]
        ports:
        - containerPort: 80
        volumeMounts:
        - mountPath: /data
          name: data-volume
      volumes:
      - name: data-volume
        persistentVolumeClaim:
          claimName: cfosdata

EOF
```

- delete cfosDeployment

with PVC used in deployment, even you deleted cFOS deployment, the data on /data is persistent , if you create deployment and mout /data to same PVC again. the data include license , configuration etc are still exist.

```bash
kubectl delete deployment cfos7210250-deployment -n cfostest 
```
- ### Example 2 - config cfos deployment to use emptyDir


with this configuration, the /data lifecycle share POD lifecycle. when POD gone, the data will also gone.
so if use this configuration, make use cFOS use configmap for all the configuration . and send all log to remote syslog server to prevent loss of the log.

to use emptyDir, just change spec.template.spec.volmumens to "emptyDir"

```bash
cat << EOF | kubectl apply -n cfostest -f - 
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cfos7210250-deployment
  labels:
    app: cfos
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cfos
  template:
    metadata:
      annotations:
        container.apparmor.security.beta.kubernetes.io/cfos7210250-container: unconfined
      labels:
        app: cfos
    spec:
      serviceAccountName: cfos-serviceaccount
      containers:
      - name: cfos7210250-container
        image: $cfosimage
        securityContext:
          capabilities:
              add: ["NET_ADMIN","SYS_ADMIN","NET_RAW"]
        ports:
        - containerPort: 80
        volumeMounts:
        - mountPath: /data
          name: data-volume
      volumes:
      - name: data-volume
        emptyDir: {}

EOF
```


### clean up

```bash
kubectl delete namespace cfostest
kubectl delete clusterrole configmap-reader
kubectl delete clusterrole secrets-reader
```
