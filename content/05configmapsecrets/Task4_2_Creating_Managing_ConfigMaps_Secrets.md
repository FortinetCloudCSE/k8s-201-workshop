---
title: "Task 2 - Creating and Managing ConfigMaps and Secrets"
chapter: false
linkTitle: "2-Creating ConfigMaps and Secrets"
weight: 5
---

## Objective

Learn how cFOS can use ConfigMaps and Secrets to Config itself

## Access External Data with ConfigMap

cFOS can continusely watch the Add/Del/Update of the ConfigMap in K8s, then use configMap data to config cFOS. 
 
ConfigMap holds configuration data for pods to consume. configuration data can be binary or text data , both is a map of string. cnofigmap data can be set to "immutable" to prevent the change. 

cFOS has build in feature can read the configMap from k8s via k8s API. when cFOS POD serviceaccount configured with a permission to read configMaps, cFOS can read configMap as it's configuration such as license data , firewall policy related config etc.,

#### Task: Create a configMap for cFOS to import license
{{< tabs >}}
{{% tab title="Create a cFOS" %}} 
- First we create CFOS without license

```bash
cd $HOME
kubectl create namespace cfostest
kubectl apply -f cfosimagepullsecret.yaml -n cfostest
kubectl apply -f $scriptDir/k8s-201-workshop/scripts/cfos/Task1_1_create_cfos_serviceaccount.yaml  -n cfostest

k8sdnsip=$(k get svc kube-dns -n kube-system -o jsonpath='{.spec.clusterIP}')
cat << EOF | tee > cfos7210250-deployment.yaml
---
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
      annotations:
        container.apparmor.security.beta.kubernetes.io/cfos7210250-container: unconfined
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
        - containerPort: 80
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
kubectl apply -f cfos7210250-deployment.yaml -n cfostest
kubectl rollout status deployment cfos7210250-deployment -n cfostest

```
{{% /tab %}}
{{% tab title="Check cFOS"  %}}

- Check cFOS running in restricted mode due to no license applied

```bash
kubectl logs --tail=100 -n cfostest -l app=cfos | grep license
```

{{% /tab %}}
{{% tab title="Configmap"  %}}

- Create a configmap file for cfos license 

{{% notice style="tip" %}}
labels "app: fos" and "category: config" are required. Especially category is used to distinguish from other ConfigMaps such as license.
cFOS only read those configMaps with label "app: fos".
{{% /notice %}}


```bash
cat <<EOF | tee cfos_license.yaml
apiVersion: v1
kind: ConfigMap
metadata:
    name: cfos-license
    labels:
        app: fos
        category: license
data:
    license: |+
EOF
```
now you created a configmap with an empty cFOS license. 

{{% notice style="tip" %}}
| (Pipe): This is a block indicator used for literal style, where line breaks and leading spaces are preserved. It’s commonly used to define multi-line strings.

The |+ ensures that all the line breaks within the license text

category: license indicate this is a license 
{{% /notice %}}

{{% /tab %}}
{{% tab title="Add License"  %}}

- Add your license 

get your license file, then append the content to yaml file, replace "CFOSVLTM24000016.lic" with your actual file name

```bash
licfile="CFOSVLTM24000016.lic"
while read -r line; do printf "      %s\n" "$line"; done < $licfile >> cfos_license.yaml
```

{{% /tab %}}
{{% tab title="Apply Resource"  %}}

- Apply the resource 

```bash
kubectl create -f cfos_license.yaml -n cfostest  
```

cFOS will "watch" ConfigMap has with label= "app: fos", then import the license into cFOS.

{{% /tab %}}
{{% tab title="Check cFOS log"  %}}

- Check cFOS log 

```bash
kubectl logs -f  -l app=cfos -n cfostest
```

{{% tab title="Expected Result" style="info" %}}
Expected Result

```
2024-05-08_10:20:15.11899 INFO: 2024/05/08 10:20:15 received a new fos configmap
2024-05-08_10:20:15.11910 INFO: 2024/05/08 10:20:15 configmap name: cfos-license, labels: map[app:fos category:license]
2024-05-08_10:20:15.11911 INFO: 2024/05/08 10:20:15 got a fos license
2024-05-08_10:20:15.11955 INFO: 2024/05/08 10:20:15 importing license...
```

{{% /tab %}}
{{% /tab %}}
{{% tab title="Verify license"  %}}
- Check whether license applied from cFOS cli

```bash
podname=$(kubectl get pod -n cfostest -l app=cfos -o jsonpath='{.items[*].metadata.name}')
kubectl exec -it po/$podname -n cfostest -- /bin/cli
```
input username "admin", the default password has not been setup, just press enter key.
then issue command

```
diag sys license
```
you shall see output like
```
cFOS # diagnose sys license
Status: Valid license
SN: CFOSVLTM240000**
Valid From: 2024-05-23
Valid To: 2024-07-25
```
use `exit` to exit the cFOS command parser 


{{% /tab %}}
{{% tab title="License troubleshooting"  %}}

- Troubleshooting license apply issue

In case you hit license issue, shell into cFOS, run `execute update-now` to check more detail

{{% /tab %}}
{{< /tabs >}}


#### Task 2 - Use cFOS ConfigMap for Firewall VIP config


{{< tabs >}}
{{% tab title="cFOS Configmap" %}}
```bash
cat << EOF | tee fosconfigmapfirewallvip.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: foscfgvip
  labels:
      app: fos
      category: config
data:
  type: partial
  config: |-
    config firewall vip
           edit "test"
               set extip "10.244.166.15"
               set mappedip "10.244.166.18"
               set extintf eth0
               set portforward enable
               set extport "8888"
               set mappedport "80"
           next
       end
EOF
kubectl create -f fosconfigmapfirewallvip.yaml -n cfostest
```
use `show firewall vip` from cFOS cli to check the cFOS vip configuration, 
cFOS configuration can contains one or more CLI commands. There are two types configurations: partial and full. For a partial configuration, it will be applied on top of current configuration in cFOS. Multiple partial configurations are accepted, so a bigger configuration can be splitted into small ones and apply them one by one. For full configuration, the active configuration will be wiped out and the new configuration will be fully restored.

{{% notice style="tip" %}}
type: partial indicates this is a partial configuration

category: config indicates this is a configuation
{{% /notice  %}}


{{% /tab %}}
{{% tab title="Check Result" style="info" %}}

- Check Result

Check cFOS container log with `kubectl logs -f  -l app=cfos -n cfostest` . you can find 

```
2024-05-14_10:57:18.63416 INFO: 2024/05/14 10:57:18 received a new fos configmap
2024-05-14_10:57:18.63417 INFO: 2024/05/14 10:57:18 configmap name: foscfgvip, labels: map[app:fos category:config]
2024-05-14_10:57:18.63417 INFO: 2024/05/14 10:57:18 got a fos config
2024-05-14_10:57:18.63417 INFO: 2024/05/14 10:57:18 applying a partial fos config...
2024-05-14_10:57:19.42525 INFO: 2024/05/14 10:57:19 fos config is applied successfully.
```

{{% /tab %}}
{{% tab title="Delete Configmap" %}}

- Delete ConfigMap

Take special care: delete a ConfigMap will not delete configuration on the running cFOS, but you can create a ConfigMap with delete command to delete the configuration. 
 - use `kubectl delete cm <configMap Name>` to delete configmap.  

{{% /tab %}}
{{% tab title="FW Configmap" %}}

- Create ConfigMap for cFOS to delete a Firewall Config

```bash
cat << EOF | kubectl create -n cfostest -f - 
apiVersion: v1
kind: ConfigMap
metadata:
  name: foscfgvip-del
  labels:
      app: fos
      category: config
data:
  type: partial
  config: |-
    config firewall vip
           del "test"
    end
EOF
```

Above will delete the configuration from cFOS. 

- Update ConfigMap

Update a Configmap will also update the configuration on cFOS

- cFOS configMap with data type: full

if data: type is set to full

cFOS will use this configuration to replace all current configuration. cFOS will be reloaded then load this function.

```bash
cat << EOF | kubectl -n cfostest apply -f - 

apiVersion: v1
data:
  config: |
  type: full
kind: ConfigMap
metadata:
  labels:
    app: fos
    category: config
  name: cm-full-empty
EOF
```
{{% /tab %}}
{{% tab title="Expected Output" style="info" %}}

Expected Result

```
kubectl logs -f -l app=cfos -n cfostest

```

```
2024-05-14_12:22:58.24465 INFO: 2024/05/14 12:22:58 received a new fos configmap
2024-05-14_12:22:58.24466 INFO: 2024/05/14 12:22:58 configmap name: cm-full-empty, labels: map[app:fos category:config]
2024-05-14_12:22:58.24466 INFO: 2024/05/14 12:22:58 got a fos config
2024-05-14_12:22:58.24493 INFO: 2024/05/14 12:22:58 applying a full fos config...
```
then cFOS will be reloaded with this empty configuraiton, effectively, this is reset cFOS back to the factory default.

{{% /tab %}}
{{< /tabs >}}

## Access External Data with Secrets

Kubernetes Secrets are objects that store sensitive data such as passwords, OAuth tokens, SSH keys, etc. The primary purpose of using secrets is to protect sensitive configuration from being exposed in your application code or script. Secrets provide a mechanism to supply containerized applications with confidential data while keeping the deployment manifests or source code non-confidential.

### Benefits of Using Secrets

- Security: Secrets keep sensitive data out of your application code and Pod definitions.
Management: Simplifies sensitive data management as updates to secrets do not require image rebuilds or application redeployments.
- Flexibility: Can be mounted as data volumes or exposed as environment variables to be used by a container in a Pod. Also, they can be used by the Kubernetes system itself for things like accessing a private image registry.

### How to Create Secrets 

- use KubeCTL or YAML file
{{< tabs >}}
{{% tab title="Using kubectl cli " %}}

```bash
kubectl create secret generic ipsec-shared-key --from-literal=ipsec-shared-pass=12345678 -n cfostest
```
{{% /tab %}}
{{% tab title="Expected Output" style="info" %}}

use `kubectl get secret ipsec-shared-key -o yaml -n cfostest` can check the secret just created.

the password "12345678" encoded with base64 and saved in k8s. you can still see the original password with 

```bash
kubectl get secret ipsec-shared-key -o json -n cfostest | jq -r '.data["ipsec-shared-pass"]' | base64 -d


```
{{% /tab %}}
{{% tab title="Using yaml File" %}}

```bash
cat << EOF | kubectl apply -n cfostest -f - 
apiVersion: v1
kind: Secret
metadata:
  name: ipsec-shared-key
data:
  ipsec-shared-pass: $(echo 12345678 | base64)
type: Opaque
EOF
```

The type field helps Kubernetes software and developers know how to treat the contents of the secret. The type Opaque is one of several predefined types that Kubernetes supports for secrets. 
{{% notice style="info" %}}
Opaque: This is the default type for a secret. It indicates that the secret contains arbitrary data that isn't structured in any predefined way specific to Kubernetes. This type is used when you are storing secret data that doesn't fit into any of the other types of secrets that Kubernetes understands (like docker-registry or tls). the other options for type are : "kubernetes.io/service-account-token:", "kubernetes.io/dockerconfigjson","kubernetes.io/tls" etc., when we create secret for store docker login secret, we have to use type: kubernetes.io/dockerconfigjson. 
{{% /notice %}}
{{% /tab %}}
{{< /tabs >}}

### Consuming Secrets in a Pod

- Environment Variables

Secret can be passed into POD as environment variables. 

- Mount Secret as Volume

- ImagePullSecrets 

Secret can be used in field "ImagePullSecrets" in serviceaccount or POD manifest
for example. you can define a secriceaccount to include an ImagePullSecrets. or you can use secret in Pod or "Deployment" manifest for pod to pull image with secret.

- As port of ConfigMap

Secret can be part of the ConfigMap for configuration purpose. for example, we can embeded secret in configMap for cFOS.

- Use external secret management system


for example, HashiCorp Vault, AWS Secrets Manager, or Azure Key Vault . These systems can dynamically inject secrets into your applications, often using a sidecar container or a mutating webhook to provide secrets to the application securely.


### Task 1 -  use secret in configMap

{{< tabs >}}
{{% tab title="CreateSecret" %}}
- create secret with key to include the shared password 

```bash
kubectl create secret generic ipsec-psks --from-literal=psk1="12345678"
```
{{% /tab %}}
{{% tab title="clustersvc" %}}
- create a clustersvc for cfos ipsec 

create a clusterIP svc for cfos to get an ip for ipsec

```bash
kubectl apply -f $scriptDir/k8s-201-workshop/scripts/cfos/02_clusterip_cfos.yaml -n cfostest
```
{{% /tab %}}
{{% tab title="Use Secret" %}}

- use secret in configmap data

```bash
cat << EOF | kubectl apply -n cfostest -f - 
apiVersion: v1
data:
  type: partial
  config: |-
    config vpn ipsec phase1-interface
        edit "test-p1"
           set interface "eth0"
           set remote-gw 10.96.17.42
           set peertype any
           set proposal aes128-sha256 aes256-sha256 aes128gcm-prfsha256 aes256gcm-prfsha384 chacha20poly1305-prfsha256
           set psksecret {{ipsec-psks:psk1}}
           set auto-negotiate disable
         next
     end
    config vpn ipsec phase2-interface
        edit "test-p2"
            set phase1name "test-p1"
            set proposal aes128-sha1 aes256-sha1 aes128-sha256 aes256-sha256 aes128gcm aes256gcm chacha20poly1305
            set dhgrp 14 15 5
            set src-subnet 10.4.96.0 255.255.240.0
            set dst-subnet 10.0.4.0 255.255.255.0
        next
    end
kind: ConfigMap
metadata:
  labels:
    app: fos
    category: config
  name: cm-ipsecvpn
EOF
```

in above configmap. inside the configuration. the line `set psksecret {{ipsec-psks:psk1}}` is reference to a secret. the secret name is "ipsec-psks", the key is psk1. the actual psksecret "12345678" is saved inside the key "psk1" of secret "ipsec-psks". 

{{% /tab %}}
{{% tab title="K8s secret" %}}
k8s configmap does not support use secret in config data. it is up to cFOS application to parse secret. In above, it is cFOS responsibility to substitute {{ipsec-psks:psk1}} with actual k8s secret ipsec-psks. 

use 
```bash
podname=$(kubectl get pod -n cfostest -l app=cfos -o jsonpath='{.items[*].metadata.name}')
kubectl exec -it po/$podname -n cfostest -- /bin/cli
```
then use `show vpn ipsec  phase1-interface` and `show vpn ipsec  phase2-interface` from cFOS cli to check cFOS configuration.

{{% /tab %}}
{{< /tabs >}}

### Summary

cFOS has build-in support for read data from k8s configMaps and Secrets , which enable multiple cFOS container in one cluster to share the configuration data. 


### clean up

```bash
kubectl delete -f cfos7210250-deployment.yaml -n cfostest
kubectl delete svc ipsec -n cfostest
kubectl delete clusterrole configmap-reader
kubectl delete clusterrole secrets-reader
kubectl delete cm cm-full-empty -n cfostest 
kubectl delete cm cm-full-empty -n cfostest
kubectl delete cm foscfgvip -n cfostest 
kubectl delete cm foscfgvip-del -n cfostest 
kubectl delete cm cm-ipsecvpn -n cfostest
```
