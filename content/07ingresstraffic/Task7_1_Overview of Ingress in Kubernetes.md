---
title: "Task 1 - Overview of Ingress in Kubernetes"
chapter: false
menuTitle: "cFOS Overview"
weight: 1
---


### cFOS overview 

Container FortiOS, the operating system that powers Fortinet's security appliance as a container, can be integrated with Kubernetes to enhance the security of inbound traffic to your containers. This integration helps ensure that only legitimate and authorized traffic reaches your Kubernetes services while providing robust security features such as intrusion prevention, application control, and advanced threat protection.


Deploying FortiOS as a containerized solution within a Kubernetes environment offers several advantages that enhance security, flexibility, and manageability. Here are some of the key benefits:

1. Enhanced Security
Advanced Threat Protection: FortiOS containers provide comprehensive security features, including firewall, intrusion prevention system (IPS), antivirus, and web filtering, offering robust protection against a wide range of threats.
SSL/TLS Inspection: Containerized FortiOS can perform SSL/TLS termination and inspection, decrypting traffic to detect hidden threats while offloading this resource-intensive task from application services.
Granular Policy Control: Allows the implementation of detailed security policies at the container level, ensuring that only legitimate traffic reaches your Kubernetes services.

2. Scalability and Flexibility
Scalable Security: FortiOS containers can scale with your Kubernetes environment, ensuring that security capabilities grow with your application demands. This is particularly useful for dynamic, microservices-based architectures.
Deployment Flexibility: Containerized FortiOS can be deployed in any Kubernetes environment, whether on-premises or in the cloud, providing consistent security across different infrastructures.

3. Integration with Kubernetes Ecosystem
Native Kubernetes Integration: FortiOS containers integrate seamlessly with Kubernetes, leveraging Kubernetes features like services, deployments, and ingress controllers to provide security at various layers.
Automation and Orchestration: Security policies and configurations can be managed and automated using Kubernetes-native tools and CI/CD pipelines, ensuring that security is integrated into the DevOps workflow.

4. Operational Efficiency
Centralized Management: Using FortiManager and FortiAnalyzer, administrators can centrally manage multiple FortiOS containers, simplifying configuration, monitoring, and reporting across large deployments.
Consistency and Standardization: Containerized deployments ensure consistent security policies and practices across different environments, reducing the risk of misconfigurations and security gaps.

5. Cost-Effectiveness
Optimized Resource Utilization: Containerized FortiOS can share resources with other containers in the Kubernetes environment, optimizing resource usage and potentially reducing infrastructure costs.
Elastic Scaling: The ability to scale security resources up or down based on demand helps manage costs more effectively, ensuring you pay only for the resources you need.

6. Improved Performance
Low Latency Security: By placing FortiOS containers close to the applications they protect within the same Kubernetes cluster, you can achieve lower latency for security processing compared to external or centralized security appliances.
Distributed Security: Security processing can be distributed across multiple nodes, enhancing performance and resilience compared to traditional, centralized security architectures.

