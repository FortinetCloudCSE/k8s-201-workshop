---
title: "How container access external data"
chapter: false
menuTitle: "Introduction to ConfigMaps and Secrets"
weight: 2
---

## Overview of how POD access external data

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

