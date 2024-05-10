---
title: "Introduction to Kubernetes Security"
chapter: false
menuTitle: "Overview of Kubernetes Security"
weight: 2
---

## Objective

This document provides an overview of security measures and strategies to protect workloads in Kubernetes, covering different phases of application lifecycle management.

## Scope of Kubernetes Security

Securing workloads in Kubernetes involves multiple layers of the technology stack, from application development to runtime enforcement.

### During Application Development Phase

- **Shift-left Approach**: Focus on software supply chain security by checking the application code and dependencies before building application containers.
  - **Tool**: Fortinet FortiDevSec is designed for this purpose.

### During Deployment Phase

- **Script Scanning**: Scan deployment scripts like Terraform and CloudFormation to ensure they follow the principle of least privilege and comply with enterprise compliance requirements.
- **Configuration Checks**: Evaluate Kubernetes configurations against best practices and compliance standards, such as CIS benchmarks.
- **Container Scanning**: Scan container images for known vulnerabilities (CVEs).
  - **Tool**: Fortinet FortiCSPM is designed for this purpose.

### Runtime Phase

- **Configuration Drift**: Continuously monitor for shifts in Kubernetes configurations, such as changes in application permissions or policies.
  - **Tool**: Fortinet FortiCSPM is also suited for this task.
- **Workload Protection**: Implement measures to protect running workloads from threats through prevention, detection, and enforcement at both the Kubernetes API server level and at the Node/Container level.
  - **Tool**: Fortinet cFOS container firewall and FortiXDR can be used for workload Protection 
  - **Tools** Fortinet Fortiweb WAF, FortiADC can be used for workload protection  for traffic entering Pods.

#### Runtime Workload Protection 

##### Prevention/Protection via Network Security 
- Actively stop unwanted traffic from entering or leaving Pods.
- Includes network security enhancements and Kubernetes network policies.
- **Tools**: Calico, Cilium provide advanced network policy enforcement. Fortinet cFOS can provide in-depth layer 7 security
##### Prvention/Protection via Application Security
- Actively stop API or Layer 4-7 traffic enter Application Pods. for example, malicous API traffic via k8s loadbalancer svc entering application POD, malicous TCP/UDP/SCTP traffic from external entering into application Pod etc., the attack is embeded in the traffic payload. 
- **Tools**: Fortinet Fortiweb, Fortinet FortiADC etc product 

##### Prevention with Detection 
- **Control Plane Monitoring**: Use Kubernetes API audit logs to detect unusual API access.
- **Runtime Monitoring**: Employ Linux agents or agentless technology  to detect unusual container syscalls, such as privilege escalation.
  - **Tool**: Fortinet XDR is designed for this purpose.

Based on the collected information, product like FortiXDR can offer real-time or near real-time response. 

#### Kubernetes API Level Security

##### RBAC

- **Least Privilege**: Provides authorization control to Kubernetes resources by granting authenticated users minimal necessary permissions.

##### Admission Control

- Controls access at the Kubernetes API level. Built-in controllers include:
  - Pod Security Policy
  - Pod Security Admission (Pod Security Standards)
- Kubernetes offers integration capabilities with external tools like OPA and Kyverno for detailed Pod security control.

#### Pod Security Contexts

- **PodSecurityContext** or **securityContext** defines privileges for individual Pods or containers, allowing specific permissions like file access or running in privileged mode.



### Network Security in Detail

This workshop focuses on Network Security with container firewall technology (cFOS).

#### Network Policies and Firewalls

- Control both ingress and egress traffic within Kubernetes. Default policies allow unrestricted traffic flow, which can be restricted using network policies based on tags.
- Kubernetes network policies support basic Layer 3-4 filtering. For Layer 7 visibility, deploying a Next-Generation Firewall (NGFW) capable of deep packet inspection alongside applications in Kubernetes can provide enhanced security.

In this workshop, We will walk through use cFOS to proect 

- Ingress traffic to Pod - North Bound
Layer 4 traffic to Pod
Layer 7 traffic to Pod

- Egress traffic from Pod to Cluster External traffic - South Bound 

POD traffic to Internet
POD traffic to Enterprise internal, such as Database in same VPC 

- Pod to Pod traffic - East-West 

Pod to Pod via Pod ipaddress
Pod to Pod via ClusterIP svc address/domain


