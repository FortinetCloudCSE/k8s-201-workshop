---
title: "Introduction to Kubernetes Security"
chapter: false
menuTitle: "Overview of Kubernetes Security"
weight: 2
---

## Objective

This document provides an overview of security measures and strategies to protect workloads in Kubernetes, covering different phases of application lifecycle management.

## Scope of Kubernetes Security

Applications running on Kubernetes include Cloud, Kubernetes Clusters, Containers, and Code (4C). Each layer of the Cloud Native security model builds upon the next outermost layer. The Code layer benefits from strong base (Cloud, Cluster, Container) security layers.

![4C](https://miro.medium.com/v2/resize:fit:1400/format:webp/0*8xMUJB2t1HBj_Vyx.png "4C image")

Securing workloads in Kubernetes involves multiple layers of the technology stack, from application development to runtime enforcement.

### During Application Development Phase

- **Shift-left Approach**: Focus on software supply chain security by checking the application code and dependencies before building application containers.

### During Deployment Phase

- **Script Scanning**: Scan deployment scripts like Terraform and CloudFormation to ensure they follow the principle of least privilege and comply with enterprise compliance requirements.
- **Configuration Checks**: Evaluate Kubernetes configurations against best practices and compliance standards, such as CIS benchmarks.
- **Container Scanning**: Scan container images for known vulnerabilities (CVEs).

### Runtime Phase

- **Configuration Drift**: Continuously monitor for shifts in Kubernetes configurations, such as changes in application permissions or policies.
- **Workload Protection**: Implement measures to protect running workloads from threats through prevention, detection, and enforcement at both the Kubernetes API server level and at the Node/Container level.

#### Runtime Workload Protection 

##### Prevention/Protection via Network Security 
- Actively stop unwanted traffic from entering or leaving Pods.
- Includes network security enhancements and Kubernetes network policies.

##### Prevention/Protection via Application Security
- Actively stop API or Layer 4-7 traffic entering Application Pods. For example, malicious API traffic via Kubernetes load balancer service entering application POD, malicious TCP/UDP/SCTP traffic from external entering into application Pod etc., the attack is embedded in the traffic payload.

##### Prevention with Detection 
- **Control Plane Monitoring**: Use Kubernetes API audit logs to detect unusual API access.
- **Runtime Monitoring**: Employ Linux agents or agentless technology to detect unusual container syscalls, such as privilege escalation.

#### Kubernetes API Level Security

##### RBAC

- **Least Privilege**: Provides authorization control to Kubernetes resources by granting authenticated users minimal necessary permissions.

##### Admission Control

- Controls access at the Kubernetes API level. Built-in controllers include:
  - Pod Security Policy
  - Pod Security Admission (Pod Security Standards)
- Kubernetes offers integration capabilities with external tools like OPA and Kyverno for detailed Pod security control.

#### Pod Security Contexts and Container SecurityContext 

- **PodSecurityContext** or **securityContext** defines privileges for individual Pods or containers, allowing specific permissions like file access or running in privileged mode.

#### Config for cFOS
Container require Linux capabilities to be functional. The container runtime by default has already granted most common Linux capabilities, for example, *cri1.25.4* version has below:
\```
"CAP_CHOWN",
"CAP_DAC_OVERRIDE",
"CAP_FSETID",
"CAP_FOWNER",
"CAP_SETGID",
"CAP_SETUID",
"CAP_SETPCAP",
"CAP_NET_BIND_SERVICE",
"CAP_KILL"
\```
Some applications like cFOS may need more privilege to be fully functional, for example, the *CAP_NET_RAW* is not in the list, then you will not be able to use *ping* function inside the cFOS container.

*NET_RAW*:
- Use RAW and PACKET sockets
- Bind to any address for transparent proxying
- This capability allows the program to craft IP packets from scratch, which includes sending and receiving ICMP packets (used in tools like ping).

*NET_ADMIN*:
- Grants a process extensive capabilities over network configuration and operations, such as NAT, iptables, etc.

*SYS_ADMIN*:
- It might be necessary for some advanced operations, such as configuring system-wide logging settings or manipulating system logs.

\```bash
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
        image: interbeing/fos:latest
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
              add: ["NET_ADMIN","NET_RAW"]
        ports:
        - containerPort: 80
        volumeMounts:
        - mountPath: /data
          name: data-volume
      volumes:
      - name: data-volume
        emptyDir: {}
\```

#### Other configuration options for securityContext

- pod.spec.containers.allowPrivilegeEscalation
  - AllowPrivilegeEscalation controls whether a process can gain more privileges than its parent process.

- pod.spec.containers.privileged
  - Run container in privileged mode. Processes in privileged containers are essentially equivalent to root on the host.

For most containers, these two options shall be set to false. Other options like `runAsUser` and `runAsGroup` can specify a user and group ID for running the container. Applications like firewalls will require running as the root user.

### Network Security in Detail

This workshop focuses on Network Security with container firewall technology (cFOS).

#### Network Policies and Firewalls

- Control both ingress and egress traffic within Kubernetes. Default policies allow unrestricted traffic flow, which can be restricted using network policies based on tags.
- Kubernetes network policies support basic Layer 3-4 filtering. For Layer 7 visibility, deploying a Next-Generation Firewall (NGFW) capable of deep packet inspection alongside applications in Kubernetes can provide enhanced security.

In this workshop, We will walk through using cFOS to protect:

- Ingress traffic to Pod - North Bound
  - Layer 4 traffic to Pod
  - Layer 7 traffic to Pod

- Egress traffic from Pod to Cluster External traffic - South Bound 
  - POD traffic to Internet
  - POD traffic to Enterprise internal, such as Database in the same VPC 

- Pod to Pod traffic - East-West 
  - Pod to Pod via Pod IP address
  - Pod to Pod via ClusterIP svc address/domain

