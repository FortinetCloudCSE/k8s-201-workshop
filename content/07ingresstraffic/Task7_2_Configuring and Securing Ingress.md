---
title: "Task 2 - Configuring and Securing Ingress"
chapter: false
menuTitle: "Ingress with cFOS"
weight: 5
---

### Purpose

In this chapter, we are going to use cFOS to do an ingress Protection for target application.
the target application is a web server which allow you to upload files. without use cFOS to pretect it,user can upload malicious file.
but cFOS providing protection, cFOS can scan uploaded file , block it if its malicious.


We use loadbalancer with public ip to get ingress traffic to target application. without use cFOS, the incoming traffic will go directly to backend application, with cFOS sitting in the middle, the loadbalancer will take the traffic to cFOS, then cFOS will use Firewall VIP redirect traffic to backend application with deep inspection.   


**traffic diagram without use cFOS**

![direct](../images/direct.png)

**traffic diagram after use cFOS in the middle**

with cFOS in the middle, it function as a reverse proxy.
![proxyed](../images/trafficcfos.png)


###  get cFOS license and imagepullsecret ready

you shall already have cFOS license and cFOS image pull secret ready. if not. complete the task in Chapater 1 ,task 3. 


**cFOS installation:**

To install cFOS we have few steps. 

1. Create a name space for cfos ingress.

```bash
kubectl create namespace cfosingress
```

2. Create a Secret and config map reader roles and role bindings. 

cFOS container will require priviledge to read configmap and secret from k8s, we will need create role for this. 
if you interested to know more about role and role/binding. 


```bash
kubectl create -f $scriptDir/k8s-201-workshop/scripts/cfos/ingress_demo/01_create_cfos_account.yaml -n cfosingress
```

output:

```
clusterrole.rbac.authorization.k8s.io/configmap-reader configured
rolebinding.rbac.authorization.k8s.io/read-configmaps configured
clusterrole.rbac.authorization.k8s.io/secrets-reader configured
rolebinding.rbac.authorization.k8s.io/read-secrets configured
```

3. create cfosimagepullsecret
you shall already created cfosimagepullsecret in Chapter 1 task 3. but if you have not . you can use below script to create it.

```bash
read -p "Paste your accessToken:|  " accessToken
echo $accessToken 
[ -n "$accessToken" ] && $scriptDir/k8s-201-workshop/scripts/cfos/imagepullsecret.yaml.sh || echo "please set \$accessToken"
kubectl apply -f cfosimagepullsecret.yaml -n cfosingress

```

4. Create a configmap file for cfos license

you shall already created configmap in Chapter 1 task 3. but if you have not . you can use below script to create it.
get your license file, then append the content to yaml file, replace “cfoslicense.lic” with your actual file name

```bash
cat <<EOF | tee cfos_license.yaml
apiVersion: v1
kind: ConfigMap
metadata:
    name: fos-license
    labels:
        app: fos
        category: license
data:
    license: |+
EOF

cd $HOME
cfoslicfilename="CFOSVLTM24000016.lic"
[ ! -f $cfoslicfilename ] && read -p "Input your cfos license file name :|  " cfoslicfilename 
while read -r line; do printf "      %s\n" "$line"; done < $cfoslicfilename >> cfos_license.yaml
kubectl create -f cfos_license.yaml -n cfosingress

```

5. check license configmap

use `kubectl get cm fos-license -o yaml -n cfosingress` to check whether license is correct. or use script below to check

```bash
diff -s -b <(k get cm fos-license -n cfosingress -o jsonpath='{.data}' | jq -r .license |  sed '${/^$/d}' ) $cfoslicfilename
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
```

check result with
```bash
kubectl get pod -n cfosingress
``` 
result
```
NAME                                    READY   STATUS    RESTARTS   AGE
cfos7210250-deployment-8b6d4b8b-ljjf5   1/1     Running   0          3m13s
```
if you see POD is in "ErrImagePull" instead Running, check your imagepullsecret. 

7. Create backend application and service

Lets create file upload server application and nginx applicaiton, also expose them with clusterIP svc. 
goweb and nginx application can be int any namespace. here we just use default namespace . 

```
kubectl create deployment goweb --image=interbeing/myfmg:fileuploadserverx86 
kubectl expose  deployment goweb --target-port=80  --port=80 
kubectl create deployment nginx --image=nginx 
kubectl expose deployment nginx --target-port=80 --port=80 
```
check result with 
`kubectl get svc goweb`, `kubectl get svc nginx`, `kubectl get ep goweb`, `kubectl get ep nginx`

result 
```
kubectl get svc
NAME         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
goweb        ClusterIP   10.96.131.201   <none>        80/TCP    13m
nginx        ClusterIP   10.96.200.35    <none>        80/TCP    13m
```
and
```
kubectl get ep
NAME         ENDPOINTS           AGE
goweb        10.224.0.13:80      15m
kubernetes   20.121.91.175:443   153m
nginx        10.224.0.28:80      15m
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

```
check result

```bash
kubectl get svc cfostest-headless -n cfosingress
```
result 
```
kubectl get svc cfostest-headless -n cfosingress
NAME                TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
cfostest-headless   ClusterIP   None         <none>        443/TCP   46s
```

the cfostest-headless is a headless server, so there is no CLUSTER-IP assigned. when we use dns name to reach it 
it will use dns to resolve it to it's backend application ip. for example


```bash
podname=$(kubectl get pod -n cfosingress -l app=cfos -o jsonpath='{.items[*].metadata.name}')
kubectl exec -it po/$podname -n cfosingress -- ip address 
kubectl exec -it po/$podname -n cfosingress -- ping cfostest-headless.cfosingress.svc.cluster.local
```
result

```
Defaulted container "cfos7210250-container" out of: cfos7210250-container, init-myservice (init)
PING cfostest-headless.cfosingress.svc.cluster.local (10.224.0.26): 56 data bytes
64 bytes from 10.224.0.26: seq=0 ttl=64 time=0.050 ms
64 bytes from 10.224.0.26: seq=1 ttl=64 time=0.066 ms
```
you will found the ip address 10.224.0.26 actually is cFOS interface ip. so we can use cfostest-headless.cfosingress.svc.cluster.local instead 10.224.0.26 in cFOS VIP configuratin. 


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

14. Create configmap to enable cFOS rest api on port 8080

```
cat << EOF | tee rest8080.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: restapi
  labels:
      app: fos
      category: config
data:
  type: partial
  config: |- 
     config system global
       set admin-port 8080
       set admin-server-cert "Device"
     end
EOF
kubectl apply -f rest8080.yaml -n cfosingress
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
```bash
podname=$(kubectl get pod -n cfosingress -l app=cfos -o jsonpath='{.items[*].metadata.name}')
echo $podname 
kubectl exec -it po/$podname -n cfosingress -- iptables -t nat -L -v
```

```
Chain fcn_dnat (1 references)
 pkts bytes target     prot opt in     out     source               destination         
    0     0 DNAT       tcp  --  eth0   any     anywhere             cfos7210250-deployment-76c8d56d75-7npvf  tcp dpt:8005 to:10.96.166.251:80
    0     0 DNAT       tcp  --  eth0   any     anywhere             cfos7210250-deployment-76c8d56d75-7npvf  tcp dpt:8000 to:10.96.20.122:80

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
```bash
podname=$(kubectl get pod -n cfosingress -l app=cfos -o jsonpath='{.items[*].metadata.name}')
echo $podname 
kubectl exec -it po/$podname -n cfosingress -- iptables -t nat -L -v
```
you shall see 

```
Chain fcn_nat (1 references)
 pkts bytes target     prot opt in     out     source               destination         
    0     0 MASQUERADE  tcp  --  any    any     anywhere             nginx.default.svc.cluster.local  ctorigdst cfos7210250-deployment-76c8d56d75-7npvf ctorigdstport 8005 connmark match  0x10000/0xff0000
    0     0 MASQUERADE  tcp  --  any    any     anywhere             goweb.default.svc.cluster.local  ctorigdst cfos7210250-deployment-76c8d56d75-7npvf ctorigdstport 8000 connmark match  0x10000/0xff0000

Chain fcn_prenat (1 references)
 pkts bytes target     prot opt in     out     source               destination         
    0     0 CONNMARK   all  --  eth0   any     anywhere             anywhere             state NEW CONNMARK xset 0x10000/0xff0000
```

19. Now exit out of container to expose the cFOS service through azure LB or metalla if you on self-managed k8s


```bash
cd $HOME
svcname=$(kubectl config view -o json | jq .clusters[0].cluster.server | cut -d "." -f 1 | cut -d "/" -f 3)
metallbip=$(kubectl get ipaddresspool -n metallb-system -o jsonpath='{.items[*].spec.addresses[0]}' | cut -d '/' -f 1)
echo use pool ipaddress $metallbip for svc 

cat << EOF | tee > 03_single.yaml 
apiVersion: v1
kind: Service
metadata:
  name: cfos7210250-service
  annotations:
    managedByController: fortinetcfos
    metallb.universe.tf/loadBalancerIPs: $metallbip
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
kubectl exec -it po/$podname -n cfosingress -- tail /var/log/log/virus.0
```

- clean up

```bash
kubectl delete namespace cfosingress
```
