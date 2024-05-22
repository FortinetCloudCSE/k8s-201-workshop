---
title: "Intro to ConfigMaps and Secrets"
chapter: false
menuTitle: "Intro to ConfigMaps and Secrets"
weight: 2
---

Containers running in a Kubernetes pod can access external data in various ways, each catering to different needs such as configuration, secrets, and runtime variables. Here are the most common methods:

- 1. Environment Variables
Environment variables are a fundamental way to pass configuration data to the container. They can be set in a Pod definition and can derive from various sources:
- **Directly in Pod Spec**: Defined directly within the pod’s YAML configuration.
- **From ConfigMaps**: Extract specific data from ConfigMaps and expose them as environment variables.
- **From Secrets**: Similar to ConfigMaps, but used for sensitive data.

- 2. ConfigMaps
ConfigMaps allow you to decouple configuration artifacts from image content to keep containerized applications portable. The data stored in ConfigMaps can be consumed by containers in a pod in several ways:
- **Environment Variables**: As mentioned, loading individual properties into environment variables.
- **Volume Mounts**: Mounting the entire ConfigMap as a volume. This makes all data in the ConfigMap available to the container as files in a directory.

- 3. Secrets
Secrets are used to store and manage sensitive information such as passwords, OAuth tokens, and ssh keys. They can be mounted into pods similar to ConfigMaps but are designed to be more secure.
- **Environment Variables**: Injecting secrets into environment variables.
- **Volume Mounts**: Mounting secrets as files within the container, allowing applications to read secret data directly from the filesystem.

- 4. Persistent Volumes (PVs)
Persistent Volumes are used for managing storage in the cluster and can be mounted into a pod to allow containers to read and write persistent data.
- **PersistentVolumeClaims**: Containers use a PersistentVolumeClaim (PVC) to mount a PersistentVolume at a specified mount point. This volume lives beyond the lifecycle of an individual pod.

- 5. Volumes
Apart from ConfigMaps and Secrets, Kubernetes supports several other types of volumes that can be used to load data into a container:
- **HostPath**: Mounts a file or directory from the host node’s filesystem into your pod.
- **NFS**: A network file system (NFS) volume allows an existing NFS (Network File System) share to be mounted into your pod.
- **Cloud Provider Specific Storage**: Such as AWS Elastic Block Store, Google Compute Engine persistent storage, Azure File Storage, etc.

- 6. Downward API
The Downward API allows containers to access information about the pod, including fields such as the pod’s name, namespace, and annotations, and expose this information either through environment variables or files.

- 7. Service Account Token
A Kubernetes Service Account can be used to access the Kubernetes API. The credentials of the service account (token) can automatically be placed into the pod at a well-known location (`/var/run/secrets/kubernetes.io/serviceaccount`), or can be accessed through environment variables, allowing the container to interact with the Kubernetes API.

- 8. External Data Sources
Containers can also access external data via APIs or web services during runtime. This can be any external source accessible over the network, which the container can access using its networking capabilities.

These methods provide versatile options for passing data to containers, ensuring that Kubernetes can manage both stateless and stateful applications effectively.

As a native container build for k8s, cFOS is able to leverage above mechanism to access external for various purpose.

### Environment Variable


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
      env: 
        - name: LOGLEVEL
          value: "info"
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
kubectl create -f cfosPOD.yaml
```

#### Check Result
you can check whether the container has Environement variable passed from external. 
it's up to container whether to handle the passed environment or not. 

```bash
kubectl exec -it po/cfos-pod -n cfostest -- sh -c 'busybox env | grep LOGLEVEL'
```

### ConfigMap

ConfigMap holds configuration data for pods to consume. configuration data can be binary or text data , both is a map of string. cnofigmap data can be set to "immutable" to prevent the change. 

cFOS has build in feature can read the configMap from k8s via k8s API. when cFOS POD serviceaccount configured with a permission to read configMaps, cFOS can read configMap as it's configuration such as license data , firewall policy related config etc.,


#### Create a configMap for cFOS to import license
- create a configmap file for cfos license 
cFOS container use labels map[app: fos] to identify the ConfigMap.  
```bash
cat <<EOF | tee cfos_license_$USER.yaml
apiVersion: v1
kind: ConfigMap
metadata:
    name: cfos-license
    labels:
        app: fos
        category: license
data:
    license: |6
EOF
```
now you created a configmap with an empty cFOS license. 

| (Pipe): This is a block indicator used for literal style, where line breaks and leading spaces are preserved. It’s commonly used to define multi-line strings.

6 : a directive to the parser that the subsequent lines are expected to be indented by at least 6 spaces.

- add your license 
get your license file, then append the content to yaml file
```bash
while read -r line; do printf "      %s\n" "$line"; done < FGVMULTM23000022.lic >> cfos_license_$USER.yaml
```
- apply the resource 
```bash
kubectl create -f cfos_license_$USER.yaml  -n cfostest
```



cFOS will "watch" ConfigMap has with label= "app: fos", then import the license into cFOS.

From cFOS log
```bash
k logs -f po/cfos-pod -n cfostest
```
Expected Result
```
2024-05-08_10:20:15.11899 INFO: 2024/05/08 10:20:15 received a new fos configmap
2024-05-08_10:20:15.11910 INFO: 2024/05/08 10:20:15 configmap name: cfos-license, labels: map[app:fos category:license]
2024-05-08_10:20:15.11911 INFO: 2024/05/08 10:20:15 got a fos license
2024-05-08_10:20:15.11955 INFO: 2024/05/08 10:20:15 importing license...
```


#### Create ConfigMap for cFOS to read Firewall Config Read


```bash
cat << EOF | tee fosconfigmapfirewallvip.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: foscfgvip
  labels:
      app: fos
      category: config
data:
  type: partial
  config: |-
    config firewall vip
           edit "test"
               set extip "10.244.166.15"
               set mappedip "10.244.166.18"
               set extinf "eth0"
               set portforward enable
               set extport "8888"
               set mappedport "80"
           next
       end
EOF
kubectl create -f fosconfigmapfirewallvip.yaml
```

#### Create ConfigMap for cFOS to delete a Firewall Config

```bash
apiVersion: v1
kind: ConfigMap
metadata:
  name: foscfgvip
  labels:
      app: fos
      category: config
data:
  type: partial
  config: |-
    config firewall vip
           del "test"
```

