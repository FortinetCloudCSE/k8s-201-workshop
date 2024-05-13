---
title: "How container access external data"
chapter: false
menuTitle: "Storage"
weight: 2
---

## Use external data

Application like cFOS will like to persist the data such as license, configuration data, log etc to storage that outside of the POD. for example, cFOS container will like to mount /data to other Volume.

to do that, we have to create a "Volume" attached to POD for container to mount

1. field spec.template.spec.containers.volmeMounts will try to mount /data directory in cfos to Volumen /data-volume
2. field spec.template.spec.volumens define the volume with name "data-volume" and it's actual storage location 


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
        image: interbeing/fos:latest
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

- emptyDir

An emptyDir volume is created when a Pod is assigned to a Node, and it exists as long as that Pod is running on that Node. The data in an emptyDir volume is deleted when the Pod is removed.

- persistentVolumeClaim (PVC)
A persistentVolumeClaim volume is used to mount a PersistentVolume into a Pod. PersistentVolumes are a way for users to manage storage resources in the cluster and can be provisioned dynamically through StorageClasses or pre-provisioned by an administrator.

- nfs (Network File System)

An nfs volume allows an existing NFS (Network File System) share to be mounted into a Pod. NFS volumes are often used in environments where data needs to be quickly and easily shared between Pods.

- awsElasticBlockStore, gcePersistentDisk, and azureDisk


These volumes allow you to integrate Kubernetes Pods with cloud provider-specific storage solutions, like AWS EBS, GCE Persistent Disks, and Azure Disk.

## Task config cfos deployment to use emptyDir
to use emptyDir, just change spec.template.spec.volmumens to "emptyDir"

with this configuration, the /data lifecycle share POD lifecycle. when POD gone, the data will also gone.
so if use this configuration, make use cFOS use configmap for all the configuration . and send all log to remote syslog server to prevent loss of the log.


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
        image: interbeing/fos:latest
        securityContext:
#          runAsUser: 0
#          appArmorProfile: 
#            type: unconfined
          capabilities:
              add: ["NET_ADMIN","SYS_ADMIN","NET_RAW"]
        ports:
        - containerPort: 80
        volumeMounts:
        - mountPath: /data
          name: data-volume
        - mountPath: /mybinary
          name: host-temp
      volumes:
      - name: data-volume
        emptyDir: {}
      - name: host-temp
        hostPath:
          path: /cfosextrabinary
          type: DirectoryOrCreate

EOF
```


