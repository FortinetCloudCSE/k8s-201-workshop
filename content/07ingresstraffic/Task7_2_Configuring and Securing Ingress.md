---
title: "Task 2 - Configuring and Securing Ingress"
chapter: false
menuTitle: "Ingress with cFOS"
weight: 5
---

## Ingress

![imageingress](../images/ingress.png)

**cFOS installation:**

To install cFOS we have few steps. 

1. Create a name space for cfos ingress.

```bash
kubectl create namespace cfosingress
```

2. Create a Secret and config map reader roles and role bindings. 

Use of Cluster Role for ConfigMap Reading:

Configuration Access: Applications or services may need to read configurations stored in ConfigMaps to adjust their operation according to the cluster environment.
Reduced Permissions: By creating a Cluster Role that only allows reading ConfigMaps, you ensure that services or users can't alter the configuration, which helps in maintaining stability and predictability of services.

Use of Cluster Role for Secret Reading:

Sensitive Data Protection: Services or applications often need to read sensitive data at runtime to perform necessary operations like connecting to databases or accessing external APIs. A Cluster Role that allows reading Secrets can provide necessary access without exposing the ability to edit or manage these Secrets.
Security Best Practices: It ensures adherence to the principle of least privilege, reducing the risk of accidental exposure or malicious modifications.

```bash
kubectl apply -f $scriptDir/k8s-201-workshop/scripts/cfos/ingress_demo/01_create_cfos_account.yaml -n cfosingress
```

output:

```
clusterrole.rbac.authorization.k8s.io/configmap-reader configured
rolebinding.rbac.authorization.k8s.io/read-configmaps configured
clusterrole.rbac.authorization.k8s.io/secrets-reader configured
rolebinding.rbac.authorization.k8s.io/read-secrets configured
```

create cfosimagepullsecret
```bash
[ -n "$accessToken" ] && $scriptDir/k8s-201-workshop/scripts/cfos/imagepullsecret.yaml.sh || echo "please set \$accessToken"
kubectl apply -f cfosimagepullsecret.yaml -n cfosingress
kubectl get sa -n cfosingress
```
3. Create a configmap file for cfos license

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

4. get your license file, then append the content to yaml file, replace “cfoslicense.lic” with your actual file name

```bash
licfile="$scriptDir/CFOSVLTM24000016.lic"
while read -r line; do printf "      %s\n" "$line"; done < $licfile >> cfos_license.yaml
```

5. Apply the resource

 ```bash
  kubectl create -f cfos_license.yaml -n cfosingress
  ```


6. To run the cfos deployment, copy the below code. This will create a deployment that utilizes the secret, configmap that was deployed.

```bash

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
kubectl apply -f cfos7210250-deployment.yaml -n cfosingress
kubectl rollout status deployment cfos7210250-deployment -n cfosingress
```

output:

```
deployment.apps/cfos7210250-deployment created
```

7. Lets create other services that will help to test egress traffic with cFOS.

```
kubectl create deployment goweb --image=interbeing/myfmg:fileuploadserverx86 
kubectl expose  deployment goweb --target-port=80  --port=80 
kubectl create deployment nginx --image=nginx 
kubectl expose deployment nginx --target-port=80 --port=80 
```

8. Since Cfos POD IP changes each time a pod is re-created. lets create a headless service.we will use the DNS of the service in VIP configuration. the DNS in kuvbernetes follows the notation: **<servicename>.<namespace>.svc.cluster.local**

```bash
cat << EOF | tee headlessservice.yaml
apiVersion: v1
kind: Service
metadata:
  name: cfostest-headless
spec:
  clusterIP: None
  selector:
    app: cfos
  ports:
    - protocol: TCP
      port: 443
      targetPort: 443
EOF
kubectl apply -f headlessservice.yaml -n cfosingress
kubectl get svc -n cfosingress
```

9. once the services are deployed, take a note of service Cluster-IP's by running 

```
kubectl get service  -o wide 
```

output:
```
k8s52 [ ~ ]$ kubectl get service  -o wide
NAME         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE     SELECTOR
goweb        ClusterIP   10.96.20.122    <none>        80/TCP    8m36s   app=goweb
kubernetes   ClusterIP   10.96.0.1       <none>        443/TCP   3h12m   <none>
nginx        ClusterIP   10.96.166.251   <none>        80/TCP    31m     app=nginx
```

10. Install metalb loadbalancer to expose the cfos service. 

```
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.3/config/manifests/metallb-native.yaml
kubectl rollout status deployment controller -n metallb-system
```

11. create ippool for metallb 

```bash
local_ip=$(kubectl get node -o wide | grep 'control-plane' | awk '{print $6}')
cat <<EOF | tee metallbippool.yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
  - $local_ip/32
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: example
  namespace: metallb-system
EOF
```

```kubectl apply -f metallbippool.yaml```

12. Verify the ip pool is created 

```kubectl get ipaddresspool -n metallb-system```

13. Before we expose the cFOS service, we need to create VIP, Firewall policy so we can have the inbound traffic through cFOS to get to nginx, goweb applicatios.


14. To run FOS commands we need to connect to the cFOS container.

Run ```kubectl get pods -n cfosingress```

output: 

```bash
NAME                                      READY   STATUS    RESTARTS   AGE
cfos7210250-deployment-76c8d56d75-7npvf   1/1     Running   0          3m41s
```

15. get the name of cFOS pod and run the below command

```bash
podname=$(kubectl get pod -n cfosingress -l app=cfos -o jsonpath='{.items[*].metadata.name}')
echo $podname 
kubectl exec -it po/$podname -n cfosingress -- /bin/cli 
```
output:

```
User: 
```

16. User: admin, password: none just hit enter.

17. on cFOS run the command:

```
show system interface
```

output:

```
config system interface
    edit "eth0"
        set ip 10.224.0.12 255.255.255.0
        set macaddr ca:4f:53:54:d3:d9
        config ipv6
            set ip6-address fe80::c84f:53ff:fe54:d3d9/64
        end
    next
    edit "any"
    next
end
```

you can config an cFOS API access port at 8080

```
config system global
    set admin-port 8080
    set admin-server-cert "Device"
end
```

NOTE: Take note of IP address and exit out of container by typing **exit**

18. Configure configmap to create VIP on cFOS to forward the traffic to nginx. 

the `extip` on firewall vip config can use cFOS pod ip or use headless svc dns name.
since the cFOS POD IP is not persistent, it will change if cFOS container restarted, so it's better to use dns name instead , which is headless svc created for cFOS, when use headless svc dns name, it will be resolved to actual interface ip. 

```bash
nginxclusterip=$(kubectl get svc -l app=nginx  -o jsonpath='{.items[*].spec.clusterIP}')
echo $nginxclusterip
gowebclusterip=$(kubectl get svc -l app=goweb  -o jsonpath='{.items[*].spec.clusterIP}')
echo $gowebclusterip
cat << EOF | tee cfosconfigmapfirewallvip.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cfosconfigvip
  labels:
      app: fos
      category: config
data:
  type: partial
  config: |-
    config firewall vip
           edit "nginx"
            set extip "cfostest-headless.cfosingress.svc.cluster.local"
            set mappedip $nginxclusterip
            set extintf "eth0"
            set portforward enable
            set extport "8005"
            set mappedport "80"
           next
           edit "goweb"
            set extip "cfostest-headless.cfosingress.svc.cluster.local"
            set mappedip $gowebclusterip
            set extintf "eth0"
            set portforward enable
            set extport "8000"
            set mappedport "80"
           next
       end
EOF
kubectl create -f cfosconfigmapfirewallvip.yaml -n cfosingress
```

once configured, from cFOS shell , you shall able to find  from "iptables -t nat -L -v"

```
Chain fcn_dnat (1 references)
 pkts bytes target     prot opt in     out     source               destination         
    0     0 DNAT       tcp  --  eth0   any     anywhere             cfos7210250-deployment-76c8d56d75-7npvf  tcp dpt:8005 to:10.96.166.251:80
    0     0 DNAT       tcp  --  eth0   any     anywhere             cfos7210250-deployment-76c8d56d75-7npvf  tcp dpt:8000 to:10.96.20.122:80

# 
```
18. Create Firewall policy configmap to allow the inbound traffic to both the VIP's. 

```bash
cat << EOF | tee cfosconfigmapfirewallpolicy.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cfosconfigpolicy
  labels:
      app: fos
      category: config
data:
  type: partial
  config: |-
    config firewall policy
           edit 1
            set name "nginx"
            set srcintf "eth0"
            set dstintf "eth0"
            set srcaddr "all"
            set dstaddr "nginx"
            set nat enable
           next
           edit 2
            set name "goweb"
            set srcintf "eth0"
            set dstintf "eth0"
            set srcaddr "all"
            set dstaddr "goweb"
            set utm-status enable
            set av-profile default
            set nat enable
           next
       end
EOF
kubectl create -f cfosconfigmapfirewallpolicy.yaml -n cfosingress
```
once configured. you can find additional nat rule  from `iptables -t nat -L -v`
```

Chain fcn_nat (1 references)
 pkts bytes target     prot opt in     out     source               destination         
    0     0 MASQUERADE  tcp  --  any    any     anywhere             nginx.default.svc.cluster.local  ctorigdst cfos7210250-deployment-76c8d56d75-7npvf ctorigdstport 8005 connmark match  0x10000/0xff0000
    0     0 MASQUERADE  tcp  --  any    any     anywhere             goweb.default.svc.cluster.local  ctorigdst cfos7210250-deployment-76c8d56d75-7npvf ctorigdstport 8000 connmark match  0x10000/0xff0000

Chain fcn_prenat (1 references)
 pkts bytes target     prot opt in     out     source               destination         
    0     0 CONNMARK   all  --  eth0   any     anywhere             anywhere             state NEW CONNMARK xset 0x10000/0xff0000
```

19. Now exit out of container to expose the cFOS service through metallb.


```bash
cd $HOME
svcname=$(kubectl config view -o json | jq .clusters[0].cluster.server | cut -d "." -f 1 | cut -d "/" -f 3)
cat << EOF | tee > 03_single.yaml 
apiVersion: v1
kind: Service
metadata:
  name: cfos7210250-service
  annotations:
    managedByController: fortinetcfos
    metallb.universe.tf/loadBalancerIPs: 10.0.0.4
    service.beta.kubernetes.io/azure-dns-label-name: $svcname
spec:
  sessionAffinity: ClientIP
  ports:
  - port: 8080
    name: cfos-restapi
    targetPort: 8080
  - port: 8000
    name: cfos-goweb-default-1
    targetPort: 8000
    protocol: TCP
  - port: 8005
    name: cfos-nginx-default-1
    targetPort: 8005
    protocol: TCP
  selector:
    app: cfos
  type: LoadBalancer

EOF
kubectl apply -f 03_single.yaml  -n cfosingress
kubectl rollout status deployment cfos7210250-deployment -n cfosingress
sleep 5
kubectl get svc cfos7210250-service  -n cfosingress

```

20. If we now curl on the Loadbalance IP we should see the following responses:

```bash
curl  http://$svcname.$location.cloudapp.azure.com:8080
```
you shall got
```
welcome to the REST API server
```
and 
```bash
curl http://$svcname.$location.cloudapp.azure.com:8000
```
you shall see output 
```
<html><body><form enctype="multipart/form-data" action="/upload" method="post">
<input type="file" name="myFile" />
<input type="submit" value="Upload" />
</form></body></html>
```
and 
```bash
curl http://$svcname.$location.cloudapp.azure.com:8005
```

or on the browser, try http://$svcname.$location.cloudapp.azure.com:8000 or http://$svcname.$location.cloudapp.azure.com:8005

![image1](../images/api.png)

![image2](../images/nginx.png)

![image3](../images/goweb.png)

you can also verify the iptables from cfos shell with command `iptables -t nat -L -v`


```
# iptables -t nat -L -v
Chain PREROUTING (policy ACCEPT 23 packets, 1220 bytes)
 pkts bytes target     prot opt in     out     source               destination         
   66  3480 fcn_prenat  all  --  any    any     anywhere             anywhere            
   66  3480 fcn_dnat   all  --  any    any     anywhere             anywhere            

Chain INPUT (policy ACCEPT 23 packets, 1220 bytes)
 pkts bytes target     prot opt in     out     source               destination         

Chain OUTPUT (policy ACCEPT 2 packets, 143 bytes)
 pkts bytes target     prot opt in     out     source               destination         

Chain POSTROUTING (policy ACCEPT 2 packets, 143 bytes)
 pkts bytes target     prot opt in     out     source               destination         
   76  5643 fcn_nat    all  --  any    any     anywhere             anywhere            

Chain fcn_dnat (1 references)
 pkts bytes target     prot opt in     out     source               destination         
   21  1100 DNAT       tcp  --  eth0   any     anywhere             cfos7210250-deployment-76c8d56d75-7npvf  tcp dpt:8005 to:10.96.166.251:80
   22  1160 DNAT       tcp  --  eth0   any     anywhere             cfos7210250-deployment-76c8d56d75-7npvf  tcp dpt:8000 to:10.96.20.122:80

Chain fcn_nat (1 references)
 pkts bytes target     prot opt in     out     source               destination         
   21  1100 MASQUERADE  tcp  --  any    any     anywhere             nginx.default.svc.cluster.local  ctorigdst cfos7210250-deployment-76c8d56d75-7npvf ctorigdstport 8005 connmark match  0x10000/0xff0000
   22  1160 MASQUERADE  tcp  --  any    any     anywhere             goweb.default.svc.cluster.local  ctorigdst cfos7210250-deployment-76c8d56d75-7npvf ctorigdstport 8000 connmark match  0x10000/0xff0000

Chain fcn_prenat (1 references)
 pkts bytes target     prot opt in     out     source               destination         
   66  3480 CONNMARK   all  --  eth0   any     anywhere             anywhere             state NEW CONNMARK xset 0x10000/0xff0000
```

21. Try uploading the ecira file from eicar website. you should **not** see a successful upload. 

```bash

curl -F "file=@$scriptDir/k8s-201-workshop/scripts/cfos/ingress_demo/eicar_com.zip" http://$svcname.$location.cloudapp.azure.com:8000/upload
cd $HOME
```
22. To Verify: 

```kubectl get pods```

Copy the name of cfos pod:


```bash
podname=$(kubectl get pod -n cfosingress -l app=cfos -o jsonpath='{.items[*].metadata.name}')
echo $podname 
kubectl exec -it po/$podname -n cfosingress -- /bin/cli
```

Once logged in, run the log filter:

```
execute log filter device 1
execute log filter category 2
execute log  display
```

You should see an entry for eicar file being blocked. 

```
cFOS # execute log filter device 1
cFOS # execute log filter category 2
cFOS # execute log  display
date=2024-05-22 time=20:04:37 eventtime=1716408277 tz="+0000" logid="0211008192" type="utm" subtype="virus" eventtype="infected" level="warning" policyid=2 msg="File is infected." action="blocked" service="HTTP" sessionid=2 srcip=10.244.153.0 dstip=10.107.22.193 srcport=20535 dstport=80 srcintf="eth0" dstintf="eth0" proto=6 direction="outgoing" filename="eicar.com" checksum="6851cf3c" quarskip="No-skip" virus="EICAR_TEST_FILE" dtype="Virus" ref="http://www.fortinet.com/ve?vn=EICAR_TEST_FILE" virusid=2172 url="http://20.83.183.25/upload" profile="default" agent="Chrome/125.0.0.0" analyticscksum="275a021bbfb6489e54d471899f7db9d1663fc695ec2fe2a2c4538aabf651fd0f" analyticssubmit="false"

date=2024-05-22 time=20:04:37 eventtime=1716408277 tz="+0000" logid="0211008192" type="utm" subtype="virus" eventtype="infected" level="warning" policyid=2 msg="File is infected." action="blocked" service="HTTP" sessionid=1 srcip=10.244.153.0 dstip=10.107.22.193 srcport=26108 dstport=80 srcintf="eth0" dstintf="eth0" proto=6 direction="outgoing" filename="eicar.com" checksum="6851cf3c" quarskip="No-skip" virus="EICAR_TEST_FILE" dtype="Virus" ref="http://www.fortinet.com/ve?vn=EICAR_TEST_FILE" virusid=2172 url="http://20.83.183.25/upload" profile="default" agent="Chrome/125.0.0.0" analyticscksum="275a021bbfb6489e54d471899f7db9d1663fc695ec2fe2a2c4538aabf651fd0f" analyticssubmit="false"


date=2024-05-22 time=20:04:49 eventtime=1716408289 tz="+0000" logid="0211008192" type="utm" subtype="virus" eventtype="infected" level="warning" policyid=2 msg="File is infected." action="blocked" service="HTTP" sessionid=7 srcip=10.244.153.0 dstip=10.107.22.193 srcport=38707 dstport=80 srcintf="eth0" dstintf="eth0" proto=6 direction="outgoing" filename="eicar.com" checksum="6851cf3c" quarskip="No-skip" virus="EICAR_TEST_FILE" dtype="Virus" ref="http://www.fortinet.com/ve?vn=EICAR_TEST_FILE" virusid=2172 url="http://20.83.183.25/upload" profile="default" agent="Chrome/125.0.0.0" analyticscksum="275a021bbfb6489e54d471899f7db9d1663fc695ec2fe2a2c4538aabf651fd0f" analyticssubmit="false"
```


23. or you can also run the below commands to see the AV log. 

```bash
podname=$(kubectl get pod -n cfosingress -l app=cfos -o jsonpath='{.items[*].metadata.name}')
echo $podname 
kubectl exec -it po/$podname -n cfosingress -- sh
cd /var/log/log
tail virus.0
```

