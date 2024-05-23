---
title: "Task 3 - Use cases and scenarios"
chapter: false
menuTitle: "Use cases"
weight: 10
---

## Object

Understand the use case of Rolebinding and ClusterRoleBinding 


## Examples of Using Roles and ClusterRoles with Bindings in Kubernetes

Understanding when to use `Role`, `ClusterRole`, `RoleBinding`, and `ClusterRoleBinding` is crucial for proper access control within a Kubernetes environment. Here are some practical examples of each:

## Namespace-Specific Permissions with Role and RoleBinding

### Use Case: Managing Pods within a Single Namespace

- Scenario: You want to grant a user permissions to only `create` and `delete` Pods within the `development` namespace.
- Why Choose Role and RoleBinding:
  - Role: Defines permissions within a specific namespace.
  - RoleBinding: Applies those permissions to specific users within the same namespace.

### Example:

```yaml
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  namespace: development
  name: pod-manager
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["create", "delete"]

---

kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: pod-manager-binding
  namespace: development
subjects:
- kind: User
  name: "dev-user"
roleRef:
  kind: Role
  name: pod-manager
  apiGroup: rbac.authorization.k8s.io
```

## Cluster-Wide Permissions with ClusterRole and ClusterRoleBinding

### Use Case: Reading Secrets Across All Namespaces

- Scenario: A monitoring tool needs to read Secrets across all namespaces to gather configuration information.
- Why Choose ClusterRole and ClusterRoleBinding:
  - ClusterRole: Appropriate for defining permissions that span multiple namespaces.
  - ClusterRoleBinding: Applies permissions across the entire cluster.

### Example:

```yaml
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: secret-reader
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "watch"]

---

kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: secret-reader-binding
subjects:
- kind: ServiceAccount
  name: monitoring-service-account
  namespace: monitoring
roleRef:
  kind: ClusterRole
  name: secret-reader
  apiGroup: rbac.authorization.k8s.io
```

## Scoped ClusterRole with RoleBinding

### Use Case: Limiting a Cluster-Wide Role to a Specific Namespace

- Scenario: You want to allow a CI/CD tool to manage Deployments and StatefulSets, but only within the `staging` namespace.
- Why Choose ClusterRole with RoleBinding:
  - ClusterRole: Defined once and can be used across multiple scenarios.
  - RoleBinding: Limits the broad permissions of a ClusterRole to a specific namespace, enhancing security without duplicating role definitions.

### Example:

```yaml
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: deployment-manager
rules:
- apiGroups: ["apps", "extensions"]
  resources: ["deployments", "statefulsets"]
  verbs: ["get", "list", "create", "update", "delete"]

---

kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: deployment-manager-binding
  namespace: staging
subjects:
- kind: ServiceAccount
  name: cicd-tool
  namespace: cicd
roleRef:
  kind: ClusterRole
  name: deployment-manager
  apiGroup: rbac.authorization.k8s.io
```

## Summary

Choosing between `Role` and `ClusterRole` largely depends on the scope of access required. `RoleBinding` helps limit broader permissions defined in `ClusterRole` to specific namespaces, thereby providing flexibility and enhancing security through precise access control.

