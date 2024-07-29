---
title: "Task 2 - Installing Multus"
chapter: false
linkTitle: "Multus install"
weight: 10
---

## Deploying and Configuring Multus

**Step 1: Install Multus CNI** 

The most common way to install Multus is via a Kubernetes manifest file, which sets up Multus as a DaemonSet. This ensures that Multus runs on all nodes in the cluster.

- **Download the latest Multus configuration file:**

    You can find the latest configuration on the Multus GitHub repository (Multus CNI on GitHub). Typically, you would use the multus.yaml from the repo. This YAML file contains the configuration for the Multus DaemonSet along with the necessary ClusterRole, ClusterRoleBinding, and ServiceAccount.

{{% notice style="info" %}} 
```bash
kubectl apply -f https://raw.githubusercontent.com/k8snetworkplumbingwg/multus-cni/master/deployments/multus-daemonset-thick.yml
kubectl rollout status ds/kube-multus-ds -n kube-system
```
{{% /notice  %}} 

output: 

```
kubectl rollout status ds/kube-multus-ds -n kube-system
customresourcedefinition.apiextensions.k8s.io/network-attachment-definitions.k8s.cni.cncf.io created
clusterrole.rbac.authorization.k8s.io/multus created
clusterrolebinding.rbac.authorization.k8s.io/multus created
serviceaccount/multus created
configmap/multus-daemon-config created
daemonset.apps/kube-multus-ds created
Waiting for daemon set "kube-multus-ds" rollout to finish: 0 of 1 updated pods are available...
daemon set "kube-multus-ds" successfully rolled out
```

```bash
kubectl get pod -n kube-system -l app=multus
```
result
```
NAME                   READY   STATUS    RESTARTS   AGE
kube-multus-ds-qlmrf   1/1     Running   0          88s
```




You may further validate that it has ran by looking at the /etc/cni/net.d/ directory and ensure that the auto-generated /etc/cni/net.d/00-multus.conf exists corresponding to the alphabetically first configuration file.

refer [how ssh into worker node](/01gettingstarted/4_task3.html#ssh-into-your-worker-node) for detail. 

once you are in worker node, you can use `sudo cat /etc/cni/net.d/00-multus.conf` to check the multus default configuration.
below you can find multus CNI is simply **proxy** to request to azure CNI config which is **10-azure.conflist**

```
azureuser@aks-worker-27647061-vmss000000:~$ sudo cat /etc/cni/net.d/00-multus.conf  | jq .
{
  "capabilities": {
    "portMappings": true
  },
  "cniVersion": "0.3.1",
  "logLevel": "verbose",
  "logToStderr": true,
  "name": "multus-cni-network",
  "clusterNetwork": "/host/etc/cni/net.d/10-azure.conflist",
  "type": "multus-shim"
}
```



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

```bash
cat <<EOF | kubectl create -f -
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

output:

```
NAME            AGE
macvlan-conf    5d23h
```

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

```bash
cat <<EOF | kubectl create -f -
apiVersion: v1
kind: Pod
metadata:
  name: samplepod
  annotations:
    k8s.v1.cni.cncf.io/networks: macvlan-conf
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

**Cleanup:**

```kubectl delete pod samplepod```

**Step 5: What if I want more interfaces?**

You can add more interfaces to a pod by creating more custom resources and then referring to them in pod's annotation. You can also reuse configurations, so for example, to attach two macvlan interfaces to a pod, you could create a pod like so:

```bash
cat <<EOF | kubectl create -f -
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

Now inspect the pod with ```kubectl exec -it samplepod -- ip a```

output:

```sallam@master1:~$ sudo kubectl exec -it samplepod -- ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
3: eth0@if19: <BROADCAST,MULTICAST,UP,LOWER_UP,M-DOWN> mtu 1450 qdisc noqueue state UP 
    link/ether fa:ba:01:2d:d0:f9 brd ff:ff:ff:ff:ff:ff
    inet 10.244.145.152/32 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::f8ba:1ff:fe2d:d0f9/64 scope link 
       valid_lft forever preferred_lft forever
4: net1@if2: <BROADCAST,MULTICAST,UP,LOWER_UP,M-DOWN> mtu 1500 qdisc noqueue state UP 
    link/ether b6:01:1e:61:fa:06 brd ff:ff:ff:ff:ff:ff
    inet 192.168.1.215/24 brd 192.168.1.255 scope global net1
       valid_lft forever preferred_lft forever
    inet6 fe80::b401:1eff:fe61:fa06/64 scope link 
       valid_lft forever preferred_lft forever
5: net2@if2: <BROADCAST,MULTICAST,UP,LOWER_UP,M-DOWN> mtu 1500 qdisc noqueue state UP 
    link/ether 72:06:b3:1d:a4:1a brd ff:ff:ff:ff:ff:ff
    inet 192.168.1.216/24 brd 192.168.1.255 scope global net2
       valid_lft forever preferred_lft forever
    inet6 fe80::7006:b3ff:fe1d:a41a/64 scope link 
       valid_lft forever preferred_lft forever
```

Note that the annotation now reads k8s.v1.cni.cncf.io/networks: macvlan-conf,macvlan-conf. Where we have the same configuration used twice, separated by a comma.

If you were to create another custom resource with the name foo you could use that such as: k8s.v1.cni.cncf.io/networks: foo,macvlan-conf, and use any number of attachments.


**Cleanup:**

```bash
kubectl delete pod samplepod
kubectl delete net-attach-def macvlan-conf
```
