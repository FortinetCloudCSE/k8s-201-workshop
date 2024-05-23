---
title: "Task 1 - Review of Kubernetes Default Networking"
chapter: false
menuTitle: "Kubernetes Default Networking"
weight: 1
---

## What is CNI?

The Container Network Interface (CNI) is a standard that defines how network interfaces are managed in Linux containers. It's widely used in container orchestration systems, like Kubernetes, to provide networking for pods and their containers. CNI allows for a plug-and-play approach to network connectivity, supporting a range of networking tasks from basic connectivity to more advanced network configurations.

Here are some of the major CNI plugins widely used across the industry:

- Calico
- Flannel
- Weave Net
- Cilium
- Canal

To check the CNI installed on your K8s' cluster run: 

```kubectl get pods -n kube-system```

```
NAME                                    READY   STATUS    RESTARTS   AGE
coredns-787d4945fb-529hz                1/1     Running   2          17d
coredns-787d4945fb-m597j                1/1     Running   2          17d
etcd-sallammaster1                      1/1     Running   2          17d
kube-apiserver-sallammaster1            1/1     Running   2          17d
kube-controller-manager-sallammaster1   1/1     Running   2          17d
kube-multus-ds-9l62f                    1/1     Running   0          6d20h
kube-multus-ds-w9d79                    1/1     Running   1          6d20h
kube-proxy-fgb2z                        1/1     Running   2          17d
kube-proxy-nvqkb                        1/1     Running   3          17d
kube-scheduler-sallammaster1            1/1     Running   2          17d
```

```kubectl get pods -n calico-system```

```
calico-kube-controllers-6b7b9c649d-89sl9   1/1     Running   2          17d
calico-node-48wzq                          1/1     Running   3          17d
calico-node-6zwcx                          1/1     Running   2          17d
calico-typha-5488975449-5jflj              1/1     Running   3          17d
csi-node-driver-2r96w                      2/2     Running   6          17d
csi-node-driver-vqg29                      2/2     Running   4          17d
```

## Kubernetes networking basics

Networking is a central part of Kubernetes, but it can be challenging to understand exactly how it is expected to work. There are 4 distinct networking problems to address: 

1. Highly-coupled container-to-container communications: this is solved by Pods and localhost communications.
2. Pod-to-Pod communications: this is the primary focus of this document.
3. Pod-to-Service communications: this is covered by Services.
4. External-to-Service communications: this is also covered by Services.


Kubernetes is all about sharing machines among applications. Typically, sharing machines requires ensuring that two applications do not try to use the same ports. Coordinating ports across multiple developers is very difficult to do at scale and exposes users to cluster-level issues outside of their control.

## Kubernetes IP address ranges

Kubernetes clusters require to allocate non-overlapping IP addresses for Pods, Services and Nodes, from a range of available addresses configured in the following components:

1. The network plugin is configured to assign IP addresses to Pods.
2. The kube-apiserver is configured to assign IP addresses to Services.
3. The kubelet or the cloud-controller-manager is configured to assign IP addresses to Nodes.


## 1. Container-to-Container Networking

Within a pod, containers share the same IP address and port space, which means they can communicate with each other using localhost. This type of networking is the simplest in Kubernetes and is intended for tightly coupled application components that need to communicate frequently and quickly.

**Benefits:** Efficient communication due to shared network namespace; no need for IP management per container.
**Use case:** Inter-process communication within a pod, such as between a web server and a local cache or database.

## 2. Pod-to-Pod Networking

Pod-to-pod communication occurs between pods across the same or different nodes within the Kubernetes cluster. Each pod is assigned a unique IP address, irrespective of which node it resides on. This setup is enabled through a flat network model that allows direct IP routing without NAT between pods.

**Implementation:** Typically handled by a CNI (Container Network Interface) plugin that configures the underlying network to allow seamless pod-to-pod communication. Common plugins include Calico, Weave, and Flannel.

**Challenges:** Ensuring network policies are in place to control access and traffic between pods for security purposes.

![imagepod](../images/pdtopd.png)


## 3. Pod-to-Service Networking

Kubernetes services are abstractions that define a logical set of pods and a policy by which to access them. Services provide stable IP addresses and DNS names to which pods can send requests. Behind the scenes, a service routes traffic to pod endpoints based on labels and selectors.

**Benefits:** Provides a reliable and stable interface for intra-cluster service communication, handling the load balancing across multiple pods.

**Implementation:** Uses kube-proxy, which runs on every node, to route traffic or manage IP tables to direct traffic to the appropriate backend pods.

![imagesvc](../images/pdtosvc.png)

## 4. External-to-Service Networking

- External-to-service communication is handled through services exposed to the outside of the cluster. This can be achieved in several ways:

- NodePort: Exposes the service on a static port on the node’s IP. External traffic is routed to this port and then forwarded to the appropriate service.

- LoadBalancer: Integrates with external cloud load balancers, providing a public IP that is mapped to the service.

- Ingress: Manages external access to the services via HTTP/HTTPS, providing advanced routing capabilities, SSL termination, and name-based virtual hosting.

**Benefits:** Allows external users and systems to interact with applications running within the cluster in a controlled and secure manner.

**Challenges:** Requires careful configuration to ensure security, such as setting up appropriate firewall rules and security groups.

![imageinternet](../images/internettosvc.png)

These different networking types together create a flexible and powerful system for managing both internal and external communications in a Kubernetes environment. The design ensures that applications are scalable, maintainable, and accessible, which is crucial for modern cloud-native applications.