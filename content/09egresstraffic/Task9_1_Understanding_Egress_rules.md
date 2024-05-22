---
title: "Task 1 - Configuring and Securing Egress"
chapter: false
menuTitle: "Engress with cFOS"
weight: 5
---

To configure egress with a containerized FortiOS using Multus CNI in Kubernetes, and ensure that the default route for outbound traffic goes through FortiOS, you need to follow these general steps:

Key Configurations:

Multus Network Configuration: Define the network attachment definitions to enable multiple network interfaces on the pods.
Default Route Setup: Ensure that the default route for egress traffic from the application pods is through the FortiOS container.
FortiOS Egress Rules: Configure FortiOS to handle and secure outbound traffic from the Kubernetes pods.

Configuration Details:

1. Multus Network Attachment Definitions

You need to define a NetworkAttachmentDefinition for the network that will route traffic through FortiOS.
Lets create a NAD for cFOS to have the gateway IP since we will have the sample pod use 192.168.1.100 as IP


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


2. Default Route Setup for Pods

When deploying your application pods, you need to annotate them to attach to the fortios-net network. This ensures that the default route for the pod's egress traffic is through the FortiOS network interface:

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


3. Create a cFOS deployment to use multus NAD

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

4. Verify if cfos pod is running

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

5. Log in to cFos container to check the interface created by multus**

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

6. Add a firewall policy to allow outbound connectivity from application pods**

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

7. to check the outbound default route of sample pod that we have created in previous step**

```kubectl exec -it samplepod -- ip route```

output:

```
sallam@sallam-master1:~$ kubectl exec -it samplepod -- ip route
default via 192.168.1.100 dev net1 
169.254.1.1 dev eth0  scope link 
192.168.1.0/24 dev net1  proto kernel  scope link  src 192.168.1.204 
```

We see that the first route in the table shows that default route is via cFOS to confirm. 

8. we can also check in the cFOS logs if we try to ping/ssh from the sample pod. 
