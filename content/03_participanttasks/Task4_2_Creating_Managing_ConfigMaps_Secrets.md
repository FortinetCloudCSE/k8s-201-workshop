---
title: "How container access external data"
chapter: false
menuTitle: "Introduction to ConfigMaps and Secrets"
weight: 2
---


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
kubectl create -f cfos_license_$USER.yaml  -n cfostest
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
               set extinf "eth0"
               set portforward enable
               set extport "8888"
               set mappedport "80"
           next
       end
EOF
kubectl create -f fosconfigmapfirewallvip.yaml
```

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

