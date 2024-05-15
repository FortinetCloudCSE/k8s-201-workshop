---
title: "How container access external data"
chapter: false
menuTitle: "Introduction to ConfigMaps and Secrets"
weight: 2
---


## Task 1 Access External Data with ConfigMap

cFOS can continusely watch the Add/Del of the ConfigMap in K8s. then use configMap data to config cFOS. 
 

### ConfigMap

ConfigMap holds configuration data for pods to consume. configuration data can be binary or text data , both is a map of string. cnofigmap data can be set to "immutable" to prevent the change. 

cFOS has build in feature can read the configMap from k8s via k8s API. when cFOS POD serviceaccount configured with a permission to read configMaps, cFOS can read configMap as it's configuration such as license data , firewall policy related config etc.,


#### Create a configMap for cFOS to import license
- create a configmap file for cfos license 
cFOS container use labels map[app: fos] to identify the ConfigMap.  
```bash
cat <<EOF | tee cfos_license_$USER.yaml
apiVersion: v1
kind: ConfigMap
metadata:
    name: cfos-license
    labels:
        app: fos
        category: license
data:
    license: |6
EOF
```
now you created a configmap with an empty cFOS license. 

| (Pipe): This is a block indicator used for literal style, where line breaks and leading spaces are preserved. It’s commonly used to define multi-line strings.

6 : a directive to the parser that the subsequent lines are expected to be indented by at least 6 spaces.

- add your license 
get your license file, then append the content to yaml file
```bash
while read -r line; do printf "      %s\n" "$line"; done < FGVMULTM23000022.lic >> cfos_license_$USER.yaml
```
- apply the resource 
```bash
kubectl create -f cfos_license.yaml  -n cfostest
```

cFOS will "watch" ConfigMap has with label= "app: fos", then import the license into cFOS.

From cFOS log
```bash
k logs -f po/cfos-pod -n cfostest
```
Expected Result
```
2024-05-08_10:20:15.11899 INFO: 2024/05/08 10:20:15 received a new fos configmap
2024-05-08_10:20:15.11910 INFO: 2024/05/08 10:20:15 configmap name: cfos-license, labels: map[app:fos category:license]
2024-05-08_10:20:15.11911 INFO: 2024/05/08 10:20:15 got a fos license
2024-05-08_10:20:15.11955 INFO: 2024/05/08 10:20:15 importing license...
```


#### Create ConfigMap for cFOS to read Firewall Config Read


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

Above "partial" means only update config partially. 

Check Result

Check cFOS container log. you can find 

```
2024-05-14_10:57:18.63416 INFO: 2024/05/14 10:57:18 received a new fos configmap
2024-05-14_10:57:18.63417 INFO: 2024/05/14 10:57:18 configmap name: foscfgvip, labels: map[app:fos category:config]
2024-05-14_10:57:18.63417 INFO: 2024/05/14 10:57:18 got a fos config
2024-05-14_10:57:18.63417 INFO: 2024/05/14 10:57:18 applying a partial fos config...
2024-05-14_10:57:19.42525 INFO: 2024/05/14 10:57:19 fos config is applied successfully.
```

Delete a ConfigMap will not delete configuration on cFOS, however, you can create a ConfigMap with delete command to delete the configuration. 

Update a Configmap will also update the configuration on cFOS

#### Create ConfigMap for cFOS to delete a Firewall Config

```bash
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
           del "test"
```

Above will delete the configuration from cFOS. 

#### cFOS configMap with data type: full

if data: type is set to full

cFOS will use this configuration to replace all current configuration. cFOS will be reloaded then load this function.

```bash
cat << EOF | tee kubectl apply -f -n cfostest

apiVersion: v1
data:
  config: |2
  type: full
kind: ConfigMap
metadata:
  labels:
    app: fos
    category: config
  name: cm-full-empty
  namespace: default
```

Expected Result

```

2024-05-14_12:22:58.24465 INFO: 2024/05/14 12:22:58 received a new fos configmap
2024-05-14_12:22:58.24466 INFO: 2024/05/14 12:22:58 configmap name: cm-full-empty, labels: map[app:fos category:config]
2024-05-14_12:22:58.24466 INFO: 2024/05/14 12:22:58 got a fos config
2024-05-14_12:22:58.24493 INFO: 2024/05/14 12:22:58 applying a full fos config...
```
then cFOS will be reloaded with this empty configuraiton, effectively, this is reset cFOS back to the factory default.

```

### Kubernetes Secret

Kubernetes Secrets are objects that store sensitive data such as passwords, OAuth tokens, SSH keys, etc. The primary purpose of using secrets is to protect sensitive configuration from being exposed in your application code or script. Secrets provide a mechanism to supply containerized applications with confidential data while keeping the deployment manifests or source code non-confidential.

Benefits of Using Secrets

Security: Secrets keep sensitive data out of your application code and Pod definitions.
Management: Simplifies sensitive data management as updates to secrets do not require image rebuilds or application redeployments.
Flexibility: Can be mounted as data volumes or exposed as environment variables to be used by a container in a Pod. Also, they can be used by the Kubernetes system itself for things like accessing a private image registry.

### How to Use Secrets 

- Creating Secrets

Using kubectl cli 
```bash
kubectl create secret generic ipsec-shared-key --from-literal=ipsec-shared-pass=12345678
```
use `kubectl get secret ipsec-shared-key -o yaml` can check the secret just created.

the password "12345678" encoded with base64 and saved in k8s. you can still see the original password with 

```bash
k get secret ipsec-shared-key -o yaml | yq .data.ipsec-shared-pass | base64 -d

```

Using a Manifest File

```bash
cat << EOF | kubectl apply -f - 
apiVersion: v1
kind: Secret
metadata:
  name: ipsec-shared-key
type: Opaque
data:
  ipsec-shared-pass: 12345678       # base64 encoded "ipsec-shared-pass"

```

The type field helps Kubernetes software and developers know how to treat the contents of the secret. The type Opaque is one of several predefined types that Kubernetes supports for secrets. Opaque: This is the default type for a secret. It indicates that the secret contains arbitrary data that isn't structured in any predefined way specific to Kubernetes. This type is used when you are storing secret data that doesn't fit into any of the other types of secrets that Kubernetes understands (like docker-registry or tls). the other options for type are : "kubernetes.io/service-account-token:", "kubernetes.io/dockerconfigjson","kubernetes.io/tls" etc., when we create secret for store docker login secret, we have to use type: kubernetes.io/dockerconfigjson. 

- Consuming Secrets in a Pod

1. Environment Variables
Secret can be passed into POD as environment variables. 
2. Mount Secret as Volume
3. ImagePullSecrets 
Secret can be used in field "ImagePullSecrets" in serviceaccount or POD manifest
for example. you can define a secriceaccount to include an ImagePullSecrets. or you can use secret in Pod or "Deployment" manifest for pod to pull image with secret.
4. As port of ConfigMap
Secret can be part of the ConfigMap for configuration purpose. for example, we can embeded secret in configMap for cFOS.
5. Use external secret management system
for example, HashiCorp Vault, AWS Secrets Manager, or Azure Key Vault . These systems can dynamically inject secrets into your applications, often using a sidecar container or a mutating webhook to provide secrets to the application securely.

#### Task - Create image pull secret and use it in serviceaccount.

Use the kubectl create secret command to create a Docker registry secret. Replace <your-username>, <your-password>, and <your-registry-url> with your actual credentials and registry URL.
```bash
kubectl create secret docker-registry cfosimagepullsecret \
  --docker-username=<your-username> \
  --docker-password=<your-password> \
  --docker-server=https://index.docker.io/v1/ \ 
  --docker-email=<your-email>
```

include cfosimagepullsecret in serviceaccount

```bash
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cfos-serviceaccount
imagePullSecrets:
- name: cfosimagepullsecret
```

#### Task - Create docker image pull secret and use it in pod manifest


secret with type : dockerconfigjson is the one used to pull docker image , to create a Kubernetes secret of type kubernetes.io/dockerconfigjson, which is used for storing a Docker registry's authentication credentials, you first need to obtain the .dockerconfigjson content. This content is essentially the base64-encoded JSON data of your Docker configuration file (~/.docker/config.json). This file gets created or updated when you log in to a Docker registry using the docker login command.

use `docker login`

```bash
docker login [registry-url]
```
if you use docker, registry-url can be omitted.

get the base64 encoded json string 
```bash
cat ~/.docker/config.json | base64
```
- create a scret yaml manifest 

```bash
apiVersion: v1
data:
  .dockerconfigjson:<<base64-encoded-docker-config-json>
kind: Secret
metadata:
  name: cfosimagepullsecret
type: kubernetes.io/dockerconfigjson

- create a cFOS yaml manifest to use imagePullSecrets

```bash
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
      containers:
      - name: cfos7210250-container
        image: interbeing/fos:latest
        securityContext:
          capabilities:
            add: ["CAP_NET_RAW","CAP_NET_ADMIN"]
        ports:
        - containerPort: 80
        volumeMounts:
        - mountPath: /data
          name: data-volume
      imagePullSecrets:
      - name: cfosimagepullsecret
      volumes:
      - name: data-volume
        emptyDir: {}
```
#### Task use secret in configMap
- create secret with key to include the shared password 

```bash
kubectl create secret generic ipsec-psks --from-literal=psk1="12345678"
```
- create a clustersvc for cfos ipsec 

```bash
cat << EOF | kubectl apply -n cfostest -f - 
apiVersion: v1
kind: Service
metadata:
  labels:
    app: cfos
  name: ipsec
spec:   
  internalTrafficPolicy: Cluster
  clusterIP: 10.110.17.42
  ipFamilies:
  - IPv4
  ipFamilyPolicy: SingleStack
  ports:
  - port: 500
    protocol: UDP
    targetPort: 500
    name: udp-500
  - port: 4500
    protocol: UDP
    targetPort: 4500
    name: udp-4500
  selector:
    app: cfos
  sessionAffinity: None
  type: ClusterIP
```

- use secret in configmap data

```bash
apiVersion: v1
data:
  type: partial
  config: |-
    config vpn ipsec phase1-interface
        edit "test-p1"
           set interface "eth0"
           set remote-gw 10.110.17.42
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
```

in above configmap. inside the configuration. the line `set psksecret {{ipsec-psks:psk1}}` is reference to a secret. the secrent name is "ipsec-psks", the key is psk1. the actual psksecret "12345678" is saved inside the key "psk1" of secret "ipsec-psks". 

k8s configmap does not support use secret in config data. it is up to cFOS application to parse secret. in above. it is cFOS responsibility to substitue {{ipsec-psks:psk1}} with actual k8s secret ipsec-psks. 



