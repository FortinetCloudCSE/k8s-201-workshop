---
title: "Deep Dive into RoleBindings and ClusterRoleBindings"
chapter: false
menuTitle: "Difference Between RoleBindings and ClusterRoleBindings"
weight: 2
---

### RoleBinding 


ClusterRole and Role can be bind to a ServiceAccount in namepsace with RoleBinding.  in K8S, a POD will use ServiceAccount to authenticate /authorizationa Pod requires a service account primarily for authentication and authorization purposes when interacting with the Kubernetes API server. the ServiceAccount will be bind to a Role/ClusterRole to get the required permission, container from that POD will have the permission to interact with the Kubernetes API server to use resources such as configmaps or secrets.

### Difference Between RoleBindings and ClusterRoleBindings

- **RoleBinding**: Applies a Role or ClusterRole within the scope of a specific namespace. Even if a ClusterRole is referenced in a RoleBinding, it only grants the permissions defined in that ClusterRole within the namespace where the RoleBinding is created.

- **ClusterRoleBinding**: Applies a ClusterRole across the entire cluster. This means the permissions granted by the ClusterRole are effective in all namespaces, as well as on cluster-scoped resources.

A typical usage will be "Kind: Role" + RoleBinding or "Kind:ClusterRole" + RoleBinding and "Kind:ClusterRole" + "ClusterRoleBinding"

Use "Kind:ClusterRole" + RoleBinding is usually for Reusability and Policy Management.

- **Reusability**: ClusterRoles can be more flexible if there is any anticipation that the same set of permissions might need to be applied to multiple namespaces in the future. With a ClusterRole, you only need to create additional RoleBindings in other namespaces without duplicating the role definition.

- **Policy Management**: In larger organizations, using ClusterRoles can simplify management by centralizing role definitions. This allows for consistent policy enforcement across multiple namespaces by binding the ClusterRole in different namespaces as needed.

The common use case for ClusterRole+RoleBinding usually uses the least privilege principle. the ClusterRole with least permission can be uniformly applied across many namespaces.

