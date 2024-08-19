---
title: "Task 1 - Introduction to Kubernetes Security"
chapter: false
linkTitle: "1-Kubernetes Security"
weight: 1
---

## Objective

This document provides an overview of security measures and strategies to protect workloads in Kubernetes, covering different phases of application lifecycle management.

## Scope of Kubernetes Security

Applications running on Kubernetes include Cloud, Kubernetes Clusters, Containers, and Code (4C). Each layer of the Cloud Native security model builds upon the next outermost layer. The Code layer benefits from strong base (Cloud, Cluster, Container) security layers.

![4C](https://www.thinktecture.com/storage/2022/02/4cs-of-cloud-native-security.png "4C image")

Securing workloads in Kubernetes involves multiple layers of the technology stack, from application development to runtime enforcement.

### Application Development Phase

- Shift-left Approach: Focus on software supply chain security by checking the application code and dependencies before building application containers.

Tools: Fortinet Product [FortiDevSec](https://www.fortinet.com/products/fortidevsec)  is build for this purpose 
### Application Deployment Phase

- Script Scanning: Scan deployment scripts like Terraform and CloudFormation, Secret, IAM etc to ensure they follow the principle of least privilege and comply with enterprise compliance requirements.
- Configuration Checks: Evaluate Kubernetes configurations against best practices and compliance standards, such as CIS benchmarks.
- Container Scanning: Scan container images for known vulnerabilities (CVEs).

Tools: 
Fortinet Product [FortiDevSec](https://www.fortinet.com/products/fortidevsec)  , [FortiCSPM](https://www.fortinet.com/products/forticspm)  are build for this purpose 

### Application Runtime Phase

- Configuration Drift: Continuously monitor for shifts in Kubernetes configurations, such as changes in application permissions or policies.
- Workload Protection: Implement measures to protect running workloads from threats through prevention, detection, and enforcement at both the Kubernetes API server level and at the Node/Container level or enforce via Networking Policy and container firewall.

Tools:
Fortinet Product [FortiCSPM](https://www.fortinet.com/products/forticspm) can provide posture managment like Config Shift.
Fortinet Product [Fortiweb](https://www.fortinet.com/products/web-application-firewall/fortiweb) and [FortiADC](https://www.fortinet.com/products/application-delivery-controller/fortiadc) can provide application security to secure API traffic or other layer 4-7 malicious traffic coming into application POD
Fortinet Product [cFOS] can provide Network Security to secure traffic enter or leaving application POD.
Fortinet Product [FortiXDR](https://www.fortinet.com/products/fortixdr) can provide Node/Container level protection by continusly detect abnormal activites at Node/Container level.
 
##  Runtime Workload Protection 

  ### Prevention/Protection via Network Security
  - Actively stop unwanted traffic from entering or leaving Pods. 
  - Includes network security enhancements via deploy container based firewall like **cFOS** and CNI based Kubernetes network policies.

  ### Prevention/Protection via Application Security
  - Actively stop API or Layer 4-7 traffic entering Application Pods. For example, malicious API traffic via Kubernetes load balancer service entering application POD, malicious TCP/UDP/SCTP traffic from external entering into application Pod etc., the attack is embedded in the traffic payload.

  ### Prevention with Detection 
  - Control Plane Monitoring: Use Kubernetes API audit logs to detect unusual API access. 
  - Runtime Monitoring: Employ Linux agents or agentless technology to detect unusual container syscalls, such as privilege escalation.

  ### Kubernetes API Level Security

  ##### RBAC:

  - RBAC Provides authorization control to Kubernetes resources by granting authenticated users minimal necessary permissions. We will talk about RBAC in next chapter.

  ##### Admission Control:

  - Controls access at the Kubernetes API level. Built-in controllers include:
    - Pod Security Policy
    - Pod Security Admission (Pod Security Standards)

  - Kubernetes offers integration capabilities with external tools like OPA and Kyverno for detailed Pod security control.

  As of Kubernetes 1.21, PodSecurityPolicy (PSP) has been deprecated and is fully removed in Kubernetes 1.25 replaced by PSA.
  PSA can be used to evaluate the security settings of pod and container configurations to determine if they meet compliance requirements and enterprise security policies based on predefined policy levels."

  ##### Pod Security Contexts and Container SecurityContext 

  - PodSecurityContext or securityContext defines privileges for individual Pods or containers, allowing specific permissions like file access or running in privileged mode.

    - pod.spec.containers.allowPrivilegeEscalation

      AllowPrivilegeEscalation controls whether a process can gain more privileges than its parent process.

    - pod.spec.containers.privileged

      Run container in privileged mode. Processes in privileged containers are essentially equivalent to root on the host.

  For most containers, these two options shall be set to false. Other options like runAsUser and runAsGroup can specify a user and group ID for running the container. Applications like firewalls will require running as the root user.

  ##### Decide the SecurityContext for cFOS application 

  Containers, by default, inherit Linux capabilities from the container runtime, such as CRI-O or containerd. For instance, the CRI-O runtime typically grants most common Linux capabilities. Below are the capabilities provided by default in version cri1.25.4:
  ```tableGen
  "CAP_CHOWN",
  "CAP_DAC_OVERRIDE",
  "CAP_FSETID",
  "CAP_FOWNER",
  "CAP_SETGID",
  "CAP_SETUID",
  "CAP_SETPCAP",
  "CAP_NET_BIND_SERVICE",
  "CAP_KILL"
  ```
However, some network applications like cFOS may require additional privileges to be fully functional. For example, the capability CAP_NET_RAW is not included in the default list. Without CAP_NET_RAW, functions like ping cannot be executed inside the cFOS container.

Here is the brief purpose of mentioned capabilites 

  NET_RAW:
  - Use RAW and PACKET sockets
  - Bind to any address for transparent proxying
  - This capability allows the program to craft IP packets from scratch, which includes sending and receiving ICMP packets (used in tools like ping).

  NET_ADMIN:
  - Grants a process extensive capabilities over network configuration and operations, such as NAT, iptables, etc.

  SYS_ADMIN:
  - It might be necessary for some advanced operations, such as configuring system-wide logging settings or manipulating system logs.

##### Task: Fix cFOS boot permission issue  

- deploy imagepullsecret, serviceaccount 

{{< tabs title="cFOS boot permissions" >}}
{{% tab title="Deploy imagepullsecret" %}}

If you do not have valid cfosimagepullsecret.yaml, check [Create imagepullsecret](/01gettingstarted/5_task4.html#create-image-pull-secret-for-kubernetes)

```
cd $HOME
kubectl create namespace cfostest
kubectl apply -f cfosimagepullsecret.yaml -n cfostest
kubectl create -f $scriptDir/k8s-201-workshop/scripts/cfos/Task1_1_create_cfos_serviceaccount.yaml  -n cfostest
```
{{% /tab %}}
{{% tab title="cFOS Deployment" %}}
```bash
cfosimage="fortinetwandy.azurecr.io/cfos:255"
cat << EOF | tee > cfos7210250-deployment.yaml 
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
      serviceAccountName: cfos-serviceaccount
      securityContext:
        runAsUser: 0
      containers:
      - name: cfos7210250-container
        image: $cfosimage
        securityContext:
          allowPrivilegeEscalation: false
          privileged: false
          capabilities:
            add: ["NET_RAW"]
        ports:
        - containerPort: 80
        volumeMounts:
        - mountPath: /data
          name: data-volume
      volumes:
      - name: data-volume
        emptyDir: {}
EOF
kubectl apply -f cfos7210250-deployment.yaml -n cfostest 
kubectl rollout status deployment cfos7210250-deployment -n cfostest
```
{{% /tab %}}
{{% tab title="command verification" %}} 
Verify cFOS container is able to execute some command
```bash
cmd="iptables -t nat -L -v"
podname=$(kubectl get pod -n cfostest -l app=cfos -o jsonpath='{.items[*].metadata.name}')
kubectl exec -it po/$podname -n cfostest -- $cmd
```
{{% /tab %}}
{{% tab title="Expected Result" style="info" %}}
You will see error message below which indicate that the container does not have permission to run cmd
```tableGen
iptables v1.8.7 (legacy): can't initialize iptables table `nat': Permission denied (you must be root)
```
{{% /tab %}}
{{< /tabs >}}
- Try to solve the permission issue by adjust the securityContext Setting.

{{< tabs title="Hints" >}}
{{% tab title="Answer" %}}
{{% notice style="tip" %}}
add linux capabilites to ["NET_ADMIN","NET_RAW"] then check log again
{{% /notice %}}

{{% notice style="info" %}}
In above cFOS yaml, runAsUser=0, AllowPriviledgeEscalation=false, priviledged=false can be removed as they are the default setting for securityContent in current version of AKS or self-managed k8s.
{{% /notice %}}

Answer

```bash
sed -i 's/add: \["NET_RAW"\]/add: ["NET_RAW","NET_ADMIN"]/' cfos7210250-deployment.yaml
kubectl replace -f cfos7210250-deployment.yaml -n cfostest
kubectl rollout status deployment cfos7210250-deployment -n cfostest
```

{{% /tab %}}
{{% tab title="verification" %}}
Check again with below command after new pod created

```bash
cmd="iptables -t nat -L -v"
podname=$(kubectl get pod -n cfostest -l app=cfos -o jsonpath='{.items[*].metadata.name}')
kubectl exec -it po/$podname -n cfostest -- $cmd
```
{{% /tab %}}
{{% tab title="Expected Result" style="info" %}}
You should see now command is now successful 
```tableGen
Chain PREROUTING (policy ACCEPT)
target     prot opt source               destination         

Chain INPUT (policy ACCEPT)
target     prot opt source               destination         

Chain OUTPUT (policy ACCEPT)
target     prot opt source               destination         

Chain POSTROUTING (policy ACCEPT)
target     prot opt source               destination  
```
{{% /tab %}}
{{< /tabs >}}

### Prevention/Protection via Network Security

Actively stop unwanted traffic from entering or leaving Pods.
Includes network security enhancements and Kubernetes network policies.

- ##### Network Policies and Container Firewalls

cFOS is the Next Generation Layer 7 Firewall which is our key foucs in this workshop. the use case of cFOS include 

- Control both ingress and egress traffic within Kubernetes. Default policies allow unrestricted traffic flow, which can be restricted using network policies based on tags.
- Kubernetes network policies support basic Layer 3-4 filtering. For Layer 7 visibility, deploying a Next-Generation Firewall (NGFW) capable of deep packet inspection alongside applications in Kubernetes can provide enhanced security.

In this workshop, We will walk through using cFOS to protect:

- Ingress traffic to Pod - North Bound
  - Layer 4 traffic to Pod
  - Layer 7 traffic to Pod

- Egress traffic from Pod to Cluster External traffic(with Multus) - South Bound 
  - POD traffic to Internet
  - POD traffic to Enterprise internal application , such as Database in the same VPC 

- Egress traffic from Pod to Cluster External traffic(with Multus) - South Bound 
  - POD traffic to Internet
  - POD traffic to Enterprise internal, such as Database in the same VPC 

- Pod to Pod traffic - East-West (with Multus)
  - Pod to Pod via Pod IP address

### Clean up

Delete cFOS deployment, but keep cfosimagepullsecret and serivce account, we will need this later

```bash
kubectl delete namespace cfostest
kubectl delete -f $scriptDir/k8s-201-workshop/scripts/cfos/Task1_1_create_cfos_serviceaccount.yaml  -n cfostest
```

### Q&A 

- Does cFOS require run with priviledged: true ?  
