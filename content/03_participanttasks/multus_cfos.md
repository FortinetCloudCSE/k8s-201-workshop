---
title: "Multus"
chapter: false
menuTitle: "Multus"
weight: 5
---

## Kubernetes networking basics

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

<image>

## 3. Pod-to-Service Networking

Kubernetes services are abstractions that define a logical set of pods and a policy by which to access them. Services provide stable IP addresses and DNS names to which pods can send requests. Behind the scenes, a service routes traffic to pod endpoints based on labels and selectors.

**Benefits:** Provides a reliable and stable interface for intra-cluster service communication, handling the load balancing across multiple pods.

**Implementation:** Uses kube-proxy, which runs on every node, to route traffic or manage IP tables to direct traffic to the appropriate backend pods.

<image>

## 4. External-to-Service Networking

- External-to-service communication is handled through services exposed to the outside of the cluster. This can be achieved in several ways:

- NodePort: Exposes the service on a static port on the node’s IP. External traffic is routed to this port and then forwarded to the appropriate service.

- LoadBalancer: Integrates with external cloud load balancers, providing a public IP that is mapped to the service.

- Ingress: Manages external access to the services via HTTP/HTTPS, providing advanced routing capabilities, SSL termination, and name-based virtual hosting.

**Benefits:** Allows external users and systems to interact with applications running within the cluster in a controlled and secure manner.

**Challenges:** Requires careful configuration to ensure security, such as setting up appropriate firewall rules and security groups.

<image>

These different networking types together create a flexible and powerful system for managing both internal and external communications in a Kubernetes environment. The design ensures that applications are scalable, maintainable, and accessible, which is crucial for modern cloud-native applications.


## Ingress (No use of Multus)


**cFOS installation:**

To install cFOS we have few steps. 

1. Create a Secret and config map reader roles and role bindings. 

Use of Cluster Role for ConfigMap Reading:

Configuration Access: Applications or services may need to read configurations stored in ConfigMaps to adjust their operation according to the cluster environment.
Reduced Permissions: By creating a Cluster Role that only allows reading ConfigMaps, you ensure that services or users can't alter the configuration, which helps in maintaining stability and predictability of services.

Use of Cluster Role for Secret Reading:

Sensitive Data Protection: Services or applications often need to read sensitive data at runtime to perform necessary operations like connecting to databases or accessing external APIs. A Cluster Role that allows reading Secrets can provide necessary access without exposing the ability to edit or manage these Secrets.
Security Best Practices: It ensures adherence to the principle of least privilege, reducing the risk of accidental exposure or malicious modifications.


```cat <<EOF | kubectl create -f -
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  namespace: default
  name: configmap-reader
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "watch", "list"]

---

apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-configmaps
  namespace: default
subjects:
- kind: ServiceAccount
  name: default
  apiGroup: ""
roleRef:
  kind: ClusterRole
  name: configmap-reader
  apiGroup: ""

---

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
   namespace: default
   name: secrets-reader
rules:
- apiGroups: [""] # "" indicates the core API group
  resources: ["secrets"]
  verbs: ["get", "watch", "list"]

---

apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-secrets
  namespace: default
subjects:
- kind: ServiceAccount
  name: default
  apiGroup: ""
roleRef:
  kind: ClusterRole
  name: secrets-reader
  apiGroup: ""
EOF
```

output:

```
clusterrole.rbac.authorization.k8s.io/configmap-reader configured
rolebinding.rbac.authorization.k8s.io/read-configmaps configured
clusterrole.rbac.authorization.k8s.io/secrets-reader configured
rolebinding.rbac.authorization.k8s.io/read-secrets configured
```

2. Generate a license configmap that will be used for cFOS deployment. 

```git clone https://github.com/FortinetCloudCSE/k8s-201-workshop.git
cd k8s-201-workshop/scripts/cfos
sh generatecfoslicensefromvmlicense.sh <licensefile.lic>
```

3. To run the cfos deployment, copy the below code. This will create a deployment that utilizes the secret, configmap that was deployed.

```cat <<EOF | kubectl create -f - 
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
      labels:
        app: cfos
    spec:
      containers:
      - name: cfos7210250-container
        image: interbeing/fos:latest
        env:
        - name: fos-license
          valueFrom:
            configMapKeyRef:
              name: fos-license
              key: license
        securityContext:
          capabilities:
              add: ["NET_ADMIN","SYS_ADMIN","NET_RAW"]
        ports:
        - containerPort: 80
        volumeMounts:
        - mountPath: /data
          name: data-volume
      imagePullSecrets:
      - name: dockerinterbeing
      volumes:
      - name: data-volume
        hostPath:
          path: /cfosdata
          type: DirectoryOrCreate
EOF
```

output:

```
deployment.apps/cfos7210250-deployment created
```

3. Lets create other services that will help to test egress traffic with cFOS.

```
kubectl create deployment goweb --image=interbeing/myfmg:fileuploadserverx86
kubectl expose  deployment goweb --target-port=80  --port=80
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --target-port=80 --port=80 
```

4. once the services are deployed, take a note of service Cluster-IP's by running 

```
kubectl get service -o wide
```

output:
```
NAME           TYPE           CLUSTER-IP       EXTERNAL-IP   PORT(S)                                                    AGE   SELECTOR
goweb          ClusterIP      10.107.22.193    <none>        80/TCP                                                     14d   app=goweb
kubernetes     ClusterIP      10.96.0.1        <none>        443/TCP                                                    20d   <none>
nginx          ClusterIP      10.107.230.40    <none>        80/TCP                                                     12d   app=nginx
```

5. Install metalb loadbalancer to expose the cfos service. 

```
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.3/config/manifests/metallb-native.yaml
kubectl rollout status deployment controller -n metallb-system
```

6. create ippool for metallb 

```
local_ip=$(kubectl get node -o wide | grep 'control-plane' | awk '{print $6}')
cat <<EOF | tee metallbippool.yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
  - $local_ip/32
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: example
  namespace: metallb-system
EOF
```

```kubectl apply -f metallbippool.yaml```

7. Verify the ip pool is created 

```kubectl get ipaddresspool -n metallb-system```

8. Before we expose the cFOS service, we need to create VIP, Firewall policy so we can have the inbound traffic through cFOS to get to nginx, goweb applicatios.


9. To run FOS commands we need to connect to the cFOS container.

Run ```kubectl get pods```

output: 

NAME                                     READY   STATUS             RESTARTS   AGE
goweb                                    1/1     Running            1          6d22h
cfos7210250-deployment-796c859b4b-r2qjc  1/1     Running            2          11d
nginx-748c667d99-qmtn4                   1/1     Running            2          11d
samplepod                                1/1     Running            1          6d21h


10. copy the name of cFOS pod and run the below command

```kubectl exec -it cfos7210250-deployment-796c859b4b-r2qjc -- dockerinit```

output:

```
System is starting...

Firmware version is 7.2.1.0250
failed to mount /: Permission denied
failed to mount /data: Permission denied
failed to mount /tmp: Permission denied
failed to mount /run: Permission denied
Preparing environment...
Verifying license...
Starting services...
ipset v7.14: Set cannot be created: set with the same name already exists
ipset v7.14: Set cannot be created: set with the same name already exists
iptables: Chain already exists.
iptables: Chain already exists.
iptables: Chain already exists.
iptables: Chain already exists.
iptables: Chain already exists.
System is ready.

User: 
```

11. User: admin, password: none just hit enter.

12. on cFOS run the command:

```
config system interface
show
```

output:

```
config system interface
    edit "eth0"
        set ip 10.244.145.146 255.255.255.255
        set macaddr ca:4f:53:54:d3:d9
        config ipv6
            set ip6-address fe80::c84f:53ff:fe54:d3d9/64
        end
    next
    edit "any"
    next
end
```

NOTE: Take note of IP address.

13. Configure VIP to forward the traffic to nginx. 

```
config firewall vip
    edit "nginx"
        set comment "nginx"
        set extip <eth0 IP address from step 12>
        set mappedip <NGINX service ip from step 4>
        set extintf "eth0"
        set portforward enable
        set extport "8000"
        set mappedport "80"
    next
end
```

14. repeat the same for goweb to use the external interface Ip of container, Service IP of Goweb application and add a different port to for portforwarding. 

```
config firewall vip
    edit "goweb"
        set comment "goweb"
        set extip <eth0 IP address from step 12>
        set mappedip <goweb service ip from step 4>
        set extintf "eth0"
        set portforward enable
        set extport "8888"
        set mappedport "80"
    next
end
```

15. Create Firewall policy to allow the inbound traffic to both the VIP's. 

```
config firewall policy
    edit 1
        set name "nginx"
        set srcintf "eth0"
        set dstintf "eth0"
        set srcaddr "all"
        set dstaddr "nginx"
        set nat enable
    next
    edit 2
        set name "goweb"
        set srcintf "eth0"
        set dstintf "eth0"
        set srcaddr "all"
        set dstaddr "goweb"
        set utm-status enable
        set av -profile default
        set nat enable
    next
end
```

16. Now exit out of container to expose the cFOS service through metallb.


```cat <<EOF | kubectl create -f - 
apiVersion: v1
kind: Service
metadata:
  name: cfos-service
  annotations:
    metallb.universe.tf/loadBalancerIPs: 10.4.0.4
spec:
  sessionAffinity: ClientIP
  ports:
  - port: 8080
    name: cfos-restapi
    targetPort: 80
  - port: 8000
    name: cfos-nginx
    targetPort: 8000
    protocol: TCP
  - port: 8888
    name: cfos-goweb
    targetPort: 8888
    protocol: TCP
  selector:
    app: fos
  type: LoadBalancer
EOF
```

17. If we now curl on the Loadbalance IP we should see the following responses:

```
sallam@master1:~$ curl 10.4.0.4:8080
welcome to the REST API server

sallam@master1:~$ curl 10.4.0.4:8000
```
need to add output here.




## What are the challenges with single network interface?

Using a single network interface in Kubernetes can present several challenges, particularly as the scale and complexity of applications increase. Here's an overview of these challenges:

- Bandwidth Limitation: A single network interface may not provide sufficient bandwidth for all pods, leading to potential bottlenecks in network performance.

- Network Congestion: As traffic increases, a single interface can become overwhelmed, causing delays and packet loss which impact application performance.

- Security and Isolation Issues: With only one network interface, implementing fine-grained network security policies can be challenging. All traffic, regardless of its nature (management, application, storage), shares the same networking path, making it difficult to enforce security policies and isolate sensitive workloads.

- Lack of Flexibility: Different applications and workloads often require different networking setups. A single network interface limits the ability to customize network configurations to optimize the performance of specific applications or to comply with regulatory requirements.


## What is Multus?

Multus is an open-source Container Network Interface (CNI) plugin for Kubernetes that enables attaching multiple network interfaces to pods. This capability significantly enhances networking flexibility and functionality in Kubernetes environments. Here’s a more detailed look at what Multus is and how it functions:

**Core Features of Multus:**

- **Multiple Network Interfaces:** Multus allows each pod in a Kubernetes cluster to have more than one network interface. This is in contrast to the default Kubernetes networking model, which typically assigns only one network interface per pod.

- **Network Customization:** With Multus, users can configure each additional network interface using different CNI plugins. This flexibility allows for a tailored networking setup that can meet specific needs, whether for performance, security, or compliance reasons.

- **Integration with Major CNI Plugins:** Multus works as a "meta-plugin", meaning it acts as a wrapper that can manage other CNI plugins like Flannel, Calico, Weave, etc. It doesn't replace these plugins but instead allows them to be used concurrently.

- **Advanced Networking Capabilities:** By enabling multiple network interfaces, Multus supports advanced networking features such as Software Defined Networking (SDN), Network Function Virtualization (NFV), and more. It can also handle sophisticated networking technologies like SR-IOV, DPDK (Data Plane Development Kit), and VLANs.

## **How Multus Works:**

**Primary Interface:** The primary network interface of a pod is typically handled by the default Kubernetes CNI plugin, which is responsible for the standard pod-to-pod communication across the cluster.

**Secondary Interfaces:** Multus manages additional interfaces. These can be configured to connect to different physical networks, virtual networks, or to provide specialized networking functions that are separate from the default Kubernetes networking.

**Benefits of Using Multus:**

- Enhanced Network Configuration: Provides the ability to use multiple networking configurations within a single cluster, improving performance and enabling more complex networking scenarios.

- Isolation and Security: Allows for traffic isolation between different network interfaces, enhancing security and reducing the risk of cross-network interference.

- Flexibility and Scalability: Offers the flexibility to meet various application needs, from high throughput to network function virtualization, making it easier to scale applications as needed.

Multus is particularly useful in environments where advanced networking configurations are necessary, such as in telecommunications, large enterprise deployments, and applications that require high network performance and security.

<image> 


## Deploying and Configuring Multus

**Step 1: Install Multus CNI** 

The most common way to install Multus is via a Kubernetes manifest file, which sets up Multus as a DaemonSet. This ensures that Multus runs on all nodes in the cluster.

- **Download the latest Multus configuration file:**

    You can find the latest configuration on the Multus GitHub repository (Multus CNI on GitHub). Typically, you would use the multus.yaml from the repo. This YAML file contains the configuration for the Multus DaemonSet along with the necessary ClusterRole, ClusterRoleBinding, and ServiceAccount.

    ```kubectl apply -f https://raw.githubusercontent.com/k8snetworkplumbingwg/multus-cni/master/deployments/multus-daemonset-thick.yml```

    output: 

    ```
    customresourcedefinition.apiextensions.k8s.io/network-attachment-definitions.k8s.cni.cncf.io configured
    clusterrole.rbac.authorization.k8s.io/multus configured
    clusterrolebinding.rbac.authorization.k8s.io/multus configured
    serviceaccount/multus configured
    configmap/multus-daemon-config configured
    daemonset.apps/kube-multus-ds configured
    ```

    ```kubectl get pods --all-namespaces | grep -i multus```

    output:

    ```
    sallam@master1:~$ sudo kubectl get pods --all-namespaces | grep -i multus
    default            fos-multus-deployment-5c64cf64b8-jdpb4     1/1     Running   1               5d22h
    kube-system        kube-multus-ds-95mls                       1/1     Running   0               17s
    kube-system        kube-multus-ds-cx2gj                       1/1     Running   0               4s
    ```

    You may further validate that it has ran by looking at the /etc/cni/net.d/ directory and ensure that the auto-generated /etc/cni/net.d/00-multus.conf exists corresponding to the alphabetically first configuration file.


**Step 2: Creating additional interfaces**

The first thing we'll do is create configurations for each of the additional interfaces that we attach to pods. We'll do this by creating Custom Resources. Part of the quickstart installation creates a "CRD" -- a custom resource definition that is the home where we keep these custom resources -- we'll store our configurations for each interface in these.

**CNI Configurations**:

Each configuration we'll add is a CNI configuration. If you're not familiar with them, let's break them down quickly. Here's an example CNI configuration:

    {
    "cniVersion": "0.3.0",
    "type": "loopback",
    "additional": "information"
    }
    

CNI configurations are JSON, and we have a structure here that has a few things we're interested in:

- cniVersion: Tells each CNI plugin which version is being used and can give the plugin information if it's using a too late (or too early) version.
- type: This tells CNI which binary to call on disk. Each CNI plugin is a binary that's called. Typically, these binaries are stored in /opt/cni/bin on each node, and CNI executes this binary. In this case we've specified the loopback binary (which create a loopback-type network interface). If this is your first time installing Multus, you might want to verify that the plugins that are in the "type" field are actually on disk in the /opt/cni/bin directory.
- additional: This field is put here as an example, each CNI plugin can specify whatever configuration parameters they'd like in JSON. These are specific to the binary you're calling in the type field.


**Step 3: Storing a configuration as a Custom Resource**

So, we want to create an additional interface. Let's create a macvlan interface for pods to use. We'll create a custom resource that defines the CNI configuration for interfaces.

Note in the following command that there's a kind: **NetworkAttachmentDefinition**.  This is our fancy name for our configuration -- it's a custom extension of Kubernetes that defines how we attach networks to our pods.

Secondarily, note the config field. You'll see that this is a CNI configuration just like we explained earlier.

Lastly but very importantly, note under metadata the name field -- here's where we give this configuration a name, and it's how we tell pods to use this configuration. The name here is **macvlan-conf** -- as we're creating a configuration for macvlan.

Here's the command to create this example configuration:

```cat <<EOF | kubectl create -f -
apiVersion: "k8s.cni.cncf.io/v1"
kind: NetworkAttachmentDefinition
metadata:
  name: macvlan-conf
spec:
  config: '{
      "cniVersion": "0.3.0",
      "type": "macvlan",
      "master": "eth0",
      "mode": "bridge",
      "ipam": {
        "type": "host-local",
        "subnet": "192.168.1.0/24",
        "rangeStart": "192.168.1.200",
        "rangeEnd": "192.168.1.216",
        "routes": [
          { "dst": "0.0.0.0/0" }
        ],
        "gateway": "192.168.1.100"
      }
    }'
EOF
```

```kubectl get network-attachment-definitions```

Output: 

```sallam@master1:~$ kubectl get network-attachment-definitions```

NAME            AGE
macvlan-conf    5d23h

For more detail:

```kubectl describe network-attachment-definitions macvlan-conf```

```
sallam@master1:~$kubectl describe network-attachment-definitions macvlan-conf
Name:         macvlan-conf
Namespace:    default
Labels:       <none>
Annotations:  <none>
API Version:  k8s.cni.cncf.io/v1
Kind:         NetworkAttachmentDefinition
Metadata:
  Creation Timestamp:  2024-05-07T20:00:32Z
  Generation:          1
  Managed Fields:
    API Version:  k8s.cni.cncf.io/v1
    Fields Type:  FieldsV1
    fieldsV1:
      f:metadata:
        f:annotations:
          .:
          f:kubectl.kubernetes.io/last-applied-configuration:
      f:spec:
        .:
        f:config:
    Manager:         kubectl-client-side-apply
    Operation:       Update
    Time:            2024-05-07T20:00:32Z
  Resource Version:  1992658
  UID:               44920096-0def-4da5-aac6-f313abbc67dd
Spec:
  Config:  { "cniVersion": "0.3.0", "type": "macvlan", "master": "eth0", "mode": "bridge", "ipam": { "type": "host-local", "subnet": "192.168.1.0/24", "rangeStart": "192.168.1.200", "rangeEnd": "192.168.1.216", "routes": [ { "dst": "0.0.0.0/0" } ], "gateway": "192.168.1.100" } }
Events:    <none>
```

**Step 4: Creating a pod that attaches an additional interface**

We're going to create a pod. This will look familiar as any pod you might have created before, but, we'll have a special annotations field -- in this case we'll have an annotation called k8s.v1.cni.cncf.io/networks. This field takes a comma delimited list of the names of your NetworkAttachmentDefinitions as we created above. Note in the command below that we have the annotation of k8s.v1.cni.cncf.io/networks: macvlan-conf where macvlan-conf is the name we used above when we created our configuration.

Let's go ahead and create a pod (that just sleeps for a really long time) with this command:

```cat <<EOF | kubectl create -f -
apiVersion: v1
kind: Pod
metadata:
  name: samplepod
  annotations:
    k8s.v1.cni.cncf.io/networks: '[{
      "name": "macvlan-conf1",
      "default-route": ["192.168.1.100"]
    }]'
spec:
  containers:
  - name: samplepod
    command: ["/bin/ash", "-c", "trap : TERM INT; sleep infinity & wait"]
    image: alpine
EOF
```

We can inspect the pod with ```kubectl exec -it samplepod -- ip a```

output:

```
sallam@sallam-master1:~$ kubectl exec -it samplepod -- ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
3: eth0@if17: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc noqueue state UP 
    link/ether 0e:dc:b3:0e:ad:d1 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 10.244.145.150/32 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::cdc:b3ff:fe0e:add1/64 scope link tentative 
       valid_lft forever preferred_lft forever
4: net1@if2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN 
    link/ether ae:d5:3e:3b:cf:10 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 192.168.1.204/24 brd 192.168.1.255 scope global net1
       valid_lft forever preferred_lft forever
    inet6 fe80::acd5:3eff:fe3b:cf10/64 scope link tentative 
       valid_lft forever preferred_lft forever
```


**What if I want more interfaces?**

You can add more interfaces to a pod by creating more custom resources and then referring to them in pod's annotation. You can also reuse configurations, so for example, to attach two macvlan interfaces to a pod, you could create a pod like so:

```cat <<EOF | kubectl create -f -
apiVersion: v1
kind: Pod
metadata:
  name: samplepod
  annotations:
    k8s.v1.cni.cncf.io/networks: macvlan-conf,macvlan-conf
spec:
  containers:
  - name: samplepod
    command: ["/bin/ash", "-c", "trap : TERM INT; sleep infinity & wait"]
    image: alpine
EOF
```

Note that the annotation now reads k8s.v1.cni.cncf.io/networks: macvlan-conf,macvlan-conf. Where we have the same configuration used twice, separated by a comma.

If you were to create another custom resource with the name foo you could use that such as: k8s.v1.cni.cncf.io/networks: foo,macvlan-conf, and use any number of attachments.



**Step 5: Deploy CFOS to use multus interface**

Lets create a NAD for cFOS to have the gateway IP since we are having the simple pod use 192.168.1.100 as IP address in Step3:


```cat <<EOF | kubectl create -f -
apiVersion: "k8s.cni.cncf.io/v1"
kind: NetworkAttachmentDefinition
metadata:
  name: cfoscni
spec:
  config: '{
      "cniVersion": "0.3.0",
      "type": "macvlan",
      "master": "eth0",
      "mode": "bridge",
      "ipam": {
        "type": "host-local",
        "subnet": "192.168.1.0/24",
        "rangeStart": "192.168.1.100",
        "rangeEnd": "192.168.1.100",
        "gateway": "192.168.1.1"
      }
    }'
EOF
```

**Step 6: Create a cFOS deployment to use multus NAD**

```cat <<EOF | kubectl create -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fos-multus-deployment
  labels:
      app: fos-multus
spec:
  replicas: 1
  selector:
    matchLabels:
        app: fos-multus
  template:
    metadata:
      labels:
          app:  fos-multus
      annotations:
        k8s.v1.cni.cncf.io/networks: '[ { "name": "cfoscni",  "ips": [ "192.168.1.100/32" ], "mac": "CA:FE:C0:FF:00:02" } ]'
    spec:
      containers:
      - name: fos-multus
        image: srijaallam/fos:latest
        env:
        - name: fos-license
          valueFrom:
            configMapKeyRef:
              name: fos-license
              key: license
        ports:
        - containerPort: 80
        securityContext:
          runAsUser: 0
          capabilities:
            add: ["SYS_ADMIN", "NET_ADMIN", "NET_RAW"]
        volumeMounts:
        - mountPath: /data
          name: data-volume
      volumes:
      - name: data-volume
        emptyDir: {}
      imagePullSecrets:
      - name: regcred
EOF
```

**Step 7: Verify if cfos pod is running**

```kubectl get pods```

output:

```
sallam@sallam-master1:~$ kubectl get pods
NAME                                     READY   STATUS             RESTARTS   AGE
fos-multus-deployment-5c64cf64b8-jdpb4   1/1     Running            2          13d
goweb-846b59f567-42s97                   1/1     Running            0          6d
nginx-748c667d99-qmtn4                   1/1     Running            3          18d
samplepod                                1/1     Running            2          13d
```

**Step 8: Log in to cFos container to check the interface created by multus**

```kubectl exec -it <pod name> -- dockerinit```

example: ```kubectl exec -it fos-multus-deployment-5c64cf64b8-jdpb4 -- dockerinit```

output:

```

System is starting...

Firmware version is 7.2.1.0250
failed to mount /: Permission denied
failed to mount /data: Permission denied
failed to mount /tmp: Permission denied
failed to mount /run: Permission denied
Preparing environment...
Verifying license...
Starting services...
ipset v7.14: Set cannot be created: set with the same name already exists
ipset v7.14: Set cannot be created: set with the same name already exists
iptables: Chain already exists.
iptables: Chain already exists.
iptables: Chain already exists.
iptables: Chain already exists.
iptables: Chain already exists.
System is ready.

User: admin
Password: 
```

Once logged in run:

```
config system interface
show
```

output:

```
cFOS # config system interface 

cFOS (interface) # show
config system interface
    edit "eth0"
        set ip 10.244.145.149 255.255.255.255
        set macaddr 4e:f4:ba:28:0c:04
        config ipv6
            set ip6-address fe80::4cf4:baff:fe28:c04/64
        end
    next
    edit "net1"
        set ip 192.168.1.100 255.255.255.0
        set macaddr ee:cc:59:49:06:70
        config ipv6
            set ip6-address fe80::eccc:59ff:fe49:670/64
        end
    next
    edit "any"
    next
end
```

**Step 9: Add a firewall policy to allow outbound connectivity from application pods**

```
config firewall policy

    edit 1
        set name "tointernet"
        set srcintf "net1"
        set dstintf "eth0"
        set srcaddr "all"
        set dstaddr "all"
        set service "ALL"
        set nat enable
        set logtraffic all
    next
end
```

**Step 10: to check the outbound default route of sample pod that we have created in previous step**

```kubectl exec -it samplepod -- ip route```

output:

```
sallam@sallam-master1:~$ kubectl exec -it samplepod -- ip route
default via 192.168.1.100 dev net1 
169.254.1.1 dev eth0  scope link 
192.168.1.0/24 dev net1  proto kernel  scope link  src 192.168.1.204 
```

We see that the first route in the table shows that default route is via cFOS to confirm lets move to next step.
