---
title: "Task 2 - Securing pod to pod traffic"
chapter: false
menuTitle: "East-West with cFOS"
weight: 5
---

East-West traffic in the context of container-based environments, particularly with Kubernetes, refers to the data flow between different nodes or pods within the same data center or network. This type of traffic is crucial for the performance and security of microservices architectures, where multiple services need to communicate with each other frequently.

Microservices break down applications into smaller, independent services, which increases the amount of East-West traffic. Each service might be running in different containers that need to communicate with each other.

![imagespod](../images/cfosptop.png)


Since multus is already installed, let confogure and secure pod to pod traffic with CFOS.

Configuration Details:

- Create namespace for application 

```bash
kubectl create namespace app-1
```
- Create NAD - Net-Attach-DE for app-1

this nad config will insert a NIC to application pod.
it also config a few static route point to cFOS 

```bash
cat << EOF | tee > nad_10_1_200_1_1_1_1.yaml 
apiVersion: "k8s.cni.cncf.io/v1"
kind: NetworkAttachmentDefinition
metadata:
  name: nadapplication200
spec:
  config: '{
      "cniVersion": "0.3.0",
      "type": "macvlan",
      "master": "eth0",
      "mode": "bridge",
      "ipam": {
        "type": "host-local",
        "subnet": "10.1.200.0/24",
        "rangeStart": "10.1.200.20",
        "rangeEnd": "10.1.200.100",
        "routes": [
         { "dst": "1.1.1.1/32", "gw": "10.1.200.252"},
         { "dst": "34.117.186.0/24", "gw": "10.1.200.252"},
         { "dst": "10.1.100.0/24", "gw": "10.1.200.252"} 
        ],
        "gateway": "10.1.200.252"
      }
    }'
EOF
kubectl apply -f nad_10_1_200_1_1_1_1.yaml -n app-1
```
- create application deployment


```bash
cat << EOF | tee > demo_application_nad_200.yaml 
apiVersion: v1
kind: Pod
metadata:
  name: diag200
  labels: 
    app: diag
  annotations:
    k8s.v1.cni.cncf.io/networks: '[ { "name": "nadapplication200" } ]'
spec:
  containers:
  - name: praqma
    image: praqma/network-multitool
    args: 
      - /bin/sh
      - -c 
      - /usr/sbin/nginx -g "daemon off;"
    securityContext:
      capabilities:
        add: ["NET_ADMIN","SYS_ADMIN","NET_RAW"]
    volumeMounts:
    - name: host-root
      mountPath: /host
  volumes:
  - name: host-root
    hostPath:
      path: /
      type: Directory
EOF
kubectl apply -f demo_application_nad_200.yaml -n app-1
```
- create another namespace 

```bash
kubectl create namespace app-2
```

- create nad for app-2

```bash
cat << EOF | tee > nad_10_1_100_1_1_1_1.yaml 
apiVersion: "k8s.cni.cncf.io/v1"
kind: NetworkAttachmentDefinition
metadata:
  name: nadapplication100
spec:
  config: '{
      "cniVersion": "0.3.0",
      "type": "macvlan",
      "master": "eth0",
      "mode": "bridge",
      "ipam": {
        "type": "host-local",
        "subnet": "10.1.100.0/24",
        "rangeStart": "10.1.100.20",
        "rangeEnd": "10.1.100.100",
        "routes": [
         { "dst": "1.1.1.1/32", "gw": "10.1.100.252"},
         { "dst": "34.117.186.0/24", "gw": "10.1.100.252"},
         { "dst": "10.1.200.0/24", "gw": "10.1.100.252"} 
        ],
        "gateway": "10.1.100.252"
      }
    }'
EOF
kubectl apply -f nad_10_1_100_1_1_1_1.yaml  -n app-2
```
- create application deployment in app-2 namespace

```bash
cat << EOF | tee demo_application_nad_100.yaml
apiVersion: v1
kind: Pod
metadata:
  name: diag100
  labels: 
    app: diag
  annotations:
    k8s.v1.cni.cncf.io/networks: '[ { "name": "nadapplication100" } ]'
spec:
  containers:
  - name: praqma
    image: praqma/network-multitool
    args: 
      - /bin/sh
      - -c 
      - /usr/sbin/nginx -g "daemon off;"
    securityContext:
      capabilities:
        add: ["NET_ADMIN","SYS_ADMIN","NET_RAW"]
    volumeMounts:
    - name: host-root
      mountPath: /host
  volumes:
  - name: host-root
    hostPath:
      path: /
      type: Directory
EOF
kubectl apply -f demo_application_nad_100.yaml -n app-2
```


- Create NAD for cFOS 

this will create two subnets with single ip address 10.1.200.252/32  and 10.1.100.252/32 for cFOS 

**subnet 10.1.200.0/24**
```bash
kubectl create namespace $cfosnamespace
cat << EOF | tee > nad_10_1_200_252_cfos.yaml 
apiVersion: "k8s.cni.cncf.io/v1"
kind: NetworkAttachmentDefinition
metadata:
  name: cfosdefaultcni6
spec:
  config: '{
      "cniVersion": "0.3.0",
      "type": "macvlan",
      "master": "eth0",
      "mode": "bridge",
      "ipam": {
        "type": "host-local",
        "subnet": "10.1.200.0/24",
        "rangeStart": "10.1.200.252",
        "rangeEnd": "10.1.200.252",
        "gateway": "10.1.200.1"
      }
    }'
EOF
kubectl apply -f nad_10_1_200_252_cfos.yaml -n cfosegress

```
**subne 10.1.100.0/24**

```bash
cat << EOF | tee > nad_10_1_100_252_cfos.yaml  
apiVersion: "k8s.cni.cncf.io/v1"
kind: NetworkAttachmentDefinition
metadata:
  name: cfosdefaultcni6100
spec:
  config: '{
      "cniVersion": "0.3.0",
      "type": "macvlan",
      "master": "eth0",
      "mode": "bridge",
      "ipam": {
        "type": "host-local",
        "subnet": "10.1.100.0/24",
        "rangeStart": "10.1.100.252",
        "rangeEnd": "10.1.100.252",
        "gateway": "10.1.100.1"
      }
    }'
EOF
kubectl apply -f nad_10_1_100_252_cfos.yaml -n cfosegress
```

- create CFOS daemonSet 

We are creating DaemonSet instead deployment as each worker node require deployment one cfos container.
application which has route point to cFOS will always use cFOS on same worker node.

**create cfosimagepull secret**
```bash

```
**create cfos license**
```bash

```
**create serviceaccount for cFOS**
```bash
kubectl apply -f $scriptDir/k8s-201-workshop/scripts/cfos/ingress_demo/01_create_cfos_account.yaml -n $cfosnamespace
```
**deploy cfos DS**

```bash
k8sdnsip=$(k get svc kube-dns -n kube-system -o jsonpath='{.spec.clusterIP}')
cat << EOF | tee > 02_create_cfos_ds.yaml
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fos-multus-deployment
  labels:
    app: cfos
spec:
  selector:
    matchLabels:
      app: cfos
  template:
    metadata:
      annotations:
        container.apparmor.security.beta.kubernetes.io/cfos7210250-container: unconfined
        k8s.v1.cni.cncf.io/networks: '[ { "name": "cfosdefaultcni6",  "ips": [ "10.1.200.252/32" ], "mac": "CA:FE:C0:FF:00:02"  }, { "name": "cfosdefaultcni6100",  "ips": [ "10.1.100.252/32" ], "mac": "CA:FE:C0:FF:01:00" } ]'
      labels:
        app: cfos
    spec:
      initContainers:
      - name: init-myservice
        image: busybox
        command:
        - sh
        - -c
        - |
          echo "nameserver $k8sdnsip" > /mnt/resolv.conf
          echo "search default.svc.cluster.local svc.cluster.local cluster.local" >> /mnt/resolv.conf;
        volumeMounts:
        - name: resolv-conf
          mountPath: /mnt
      serviceAccountName: cfos-serviceaccount
      containers:
      - name: cfos7210250-container
        image: $cfosimage
        securityContext:
          privileged: false
          capabilities:
            add: ["NET_ADMIN","SYS_ADMIN","NET_RAW"]
        ports:
        - containerPort: 443
        volumeMounts:
        - mountPath: /data
          name: data-volume
        - mountPath: /etc/resolv.conf
          name: resolv-conf
          subPath: resolv.conf
      volumes:
      - name: data-volume
        emptyDir: {}
      - name: resolv-conf
        emptyDir: {}
      dnsPolicy: ClusterFirst
EOF
kubectl apply -f 02_create_cfos_ds.yaml -n cfosegress
kubectl rollout status daemonset fos-multus-deployment -n cfosegress

```
- create firewall policy

The firewall policy allow traffic from net1 to net2 inspected by firewall policy

```bash
cat << EOF  | tee > net1net2cmfirewallpolicy.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: net1net2
  labels:
      app: fos
      category: config
data:
  type: partial
  config: |-
    config firewall policy
      edit 10
        set utm-status enable
        set srcintf "net1"
        set dstintf "net2"
        set srcaddr "all"
        set dstaddr "all"
        set service "ALL"
        set ssl-ssh-profile "deep-inspection"
        set av-profile "default"
        set webfilter-profile "default"
        set ips-sensor "high_security"
        set logtraffic all
       next
    end
    config firewall policy
      edit 11
        set utm-status enable
        set srcintf "net2"
        set dstintf "net1"
        set srcaddr "all"
        set dstaddr "all"
        set service "ALL"
        set ssl-ssh-profile "deep-inspection"
        set av-profile "default"
        set webfilter-profile "default"
        set ips-sensor "high_security"
        set logtraffic all
       next
    end
EOF
kubectl apply -f net1net2cmfirewallpolicy.yaml  -n cfosegress
```

- get ip from diag100 and diag200

```bash
diag200ip=$(k get po/diag200 -n app-1 -o jsonpath='{.metadata.annotations}' | jq -r '.["k8s.v1.cni.cncf.io/network-status"]' | jq -r '.[1].ips[0]')
echo $diag200ip
diag100ip=$(k get po/diag100 -n app-2 -o jsonpath='{.metadata.annotations}' | jq -r '.["k8s.v1.cni.cncf.io/network-status"]' | jq -r '.[1].ips[0]')
echo $diag100ip

```
- check connectivity between diag100 to diag200
```bash
k exec -it po/diag100 -n app-2 -- ping $diag200ip
k exec -it po/diag200 -n app-1 -- ping $diag100ip
```
- Send malicious traffic

```bash
k exec -it po/diag100 -n app-2 -- curl -H "User-Agent: () { :; }; /bin/ls" http://$diag200ip
k exec -it po/diag200 -n app-1 -- curl -H "User-Agent: () { :; }; /bin/ls" http://$diag100ip


```
- Check Result

```bash
podname=$(kubectl get pod -n cfosegress -l app=cfos -o jsonpath='{.items[*].metadata.name}')
kubectl exec -it po/$podname -n cfosegress -- tail -f /data/var/log/log/ips.0


```
expected output

```
kubectl exec -it po/$podname -n cfosegress -- tail -f /data/var/log/log/ips.0
Defaulted container "cfos7210250-container" out of: cfos7210250-container, init-myservice (init)
date=2024-06-27 time=09:18:00 eventtime=1719479880 tz="+0000" logid="0419016384" type="utm" subtype="ips" eventtype="signature" level="alert" severity="critical" srcip=10.1.200.22 dstip=34.117.186.192 srcintf="net1" dstintf="eth0" sessionid=2 action="dropped" proto=6 service="HTTP" policyid=100 attack="Bash.Function.Definitions.Remote.Code.Execution" srcport=33352 dstport=80 hostname="ipinfo.io" url="/" direction="outgoing" attackid=39294 profile="high_security" incidentserialno=265289730 msg="applications3: Bash.Function.Definitions.Remote.Code.Execution"
date=2024-06-27 time=09:37:35 eventtime=1719481055 tz="+0000" logid="0419016384" type="utm" subtype="ips" eventtype="signature" level="alert" severity="critical" srcip=10.1.100.22 dstip=10.1.200.22 srcintf="net2" dstintf="net1" sessionid=10 action="dropped" proto=6 service="HTTP" policyid=11 attack="Bash.Function.Definitions.Remote.Code.Execution" srcport=46952 dstport=80 hostname="10.1.200.22" url="/" direction="outgoing" attackid=39294 profile="high_security" incidentserialno=265289733 msg="applications3: Bash.Function.Definitions.Remote.Code.Execution"
date=2024-06-27 time=09:37:41 eventtime=1719481061 tz="+0000" logid="0419016384" type="utm" subtype="ips" eventtype="signature" level="alert" severity="critical" srcip=10.1.200.22 dstip=10.1.100.22 srcintf="net1" dstintf="net2" sessionid=11 action="dropped" proto=6 service="HTTP" policyid=10 attack="Bash.Function.Definitions.Remote.Code.Execution" srcport=40358 dstport=80 hostname="10.1.100.22" url="/" direction="outgoing" attackid=39294 profile="high_security" incidentserialno=265289734 msg="applications3: Bash.Function.Definitions.Remote.Code.Execution"
```

