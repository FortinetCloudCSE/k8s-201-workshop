---
title: "Task 1 - Access External Data"
chapter: false
menuTitle: "Overview"
weight: 2
---
## Overview of how POD access external data

Containers running in a Kubernetes pod can access external data in various ways, each catering to different needs such as configuration, secrets, and runtime variables. Here are the most common methods:

- ### Environment Variables
Environment variables are a fundamental way to pass configuration data to the container. They can be set in a Pod definition and can derive from various sources:
- Directly in Pod Spec: Defined directly within the pod’s YAML configuration.
- From ConfigMaps: Extract specific data from ConfigMaps and expose them as environment variables.
- From Secrets: Similar to ConfigMaps, but used for sensitive data.

- ### ConfigMaps
ConfigMaps allow you to decouple configuration artifacts from image content to keep containerized applications portable. The data stored in ConfigMaps can be consumed by containers in a pod in several ways:
- Environment Variables: As mentioned, loading individual properties into environment variables.
- Volume Mounts: Mounting the entire ConfigMap as a volume. This makes all data in the ConfigMap available to the container as files in a directory.

- ### Secrets
Secrets are used to store and manage sensitive information such as passwords, OAuth tokens, and ssh keys. They can be mounted into pods similar to ConfigMaps but are designed to be more secure.
- Environment Variables: Injecting secrets into environment variables.
- Volume Mounts: Mounting secrets as files within the container, allowing applications to read secret data directly from the filesystem.

- ### Persistent Volumes (PVs)
Persistent Volumes are used for managing storage in the cluster and can be mounted into a pod to allow containers to read and write persistent data.
- PersistentVolumeClaims: Containers use a PersistentVolumeClaim (PVC) to mount a PersistentVolume at a specified mount point. This volume lives beyond the lifecycle of an individual pod.

- ### Volumes
Apart from ConfigMaps and Secrets, Kubernetes supports several other types of volumes that can be used to load data into a container:
- HostPath: Mounts a file or directory from the host node’s filesystem into your pod.
- NFS: A network file system (NFS) volume allows an existing NFS (Network File System) share to be mounted into your pod.
- Cloud Provider Specific Storage: Such as AWS Elastic Block Store, Google Compute Engine persistent storage, Azure File Storage, etc.

- ### Downward API
The Downward API allows containers to access information about the pod, including fields such as the pod’s name, namespace, and annotations, and expose this information either through environment variables or files.
By using the Downward API, applications can remain loosely coupled from Kubernetes APIs while still leveraging the dynamic configuration capabilities of the platform

- ### Service Account Token
A Kubernetes Service Account can be used to access the Kubernetes API. The credentials of the service account (token) can automatically be placed into the pod at a well-known location (`/var/run/secrets/kubernetes.io/serviceaccount`), or can be accessed through environment variables, allowing the container to interact with the Kubernetes API.

cFOS will use this JWT token to authenticate itself with kubernetes API to perform action like read configMap etc., 


- ### External Data Sources
Containers can also access external data via APIs or web services during runtime. This can be any external source accessible over the network, which the container can access using its networking capabilities.

These methods provide versatile options for passing data to containers, ensuring that Kubernetes can manage both stateless and stateful applications effectively.

Below is a configuration sample that allow cFOS to use external url to get a file as dstaddr in firewall policy

```bash
cat << EOF | tee cm_external_resource.yaml 
apiVersion: v1
kind: ConfigMap
metadata:
  name: cm-externalresource
  labels:
      app: fos
      category: config
data:
  type: partial
  config: |-
    config system external-resource
      edit "External-resource-files"
        set type address
        set resource "http://10.104.3.130/resources/urls"
        set refresh-rate 2
        set interface "eth0"
      next
    end
    config firewall policy
       edit 10
        set srcintf "eth0"
        set dstintf "eth0"
        set srcaddr "all"
        set dstaddr "External-resource-files"
        set action deny
       next
    end
EOF
kubectl apply -f cm_external_resource.yaml
```

after apply above yaml manifest, you can use `kubectl describe cm cm-externalresource` to check the configuration. 
if you have cFOS container running, cFOS will read this configmap and config itself accordingly. 


### clean up

```bash
cat << EOF | kubectl apply -f - 
apiVersion: v1
data:
  config: |2
  type: full
kind: ConfigMap
metadata:
  labels:
    app: fos
    category: config
  name: cm-full-empty
EOF
kubectl delete cm cm-externalresource
kubectl delete cm cm-full-empty
```

the `kubectl delete cm cm-externalresource` will delete cm-externalresource configmap from k8s, but this will not delete config on cFOS. so we create a empty config with type "full" to reset cFOS config to factory default. this will remove all configuration which include cm-externalresource from cFOS

 

