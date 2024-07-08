
### Create cluster
./create_kubeadm_k8s_on_ubuntu22.sh
or just use standard aks

### Install multus
./install_multus.sh

### install net-att-def for app-1

```bash
kubectl create namespace app-1
kubectl apply -f nad_10_1_200_1_1_1_1.yaml -n app-1
kubectl apply -f demo_application_nad_200.yaml -n app-1
```

```bash
kubectl create namespace app-2
kubectl apply -f nad_10_1_100_1_1_1_1.yaml -n app-2
kubectl apply -f demo_application_nad_100.yaml -n app-2
```

get ip from applcation 

```
$ k exec -it po/diag200 -n app-1 -- ip address show dev net1 | grep 'inet 10.1'
    inet 10.1.200.20/24 brd 10.1.200.255 scope global net1
$ k exec -it po/diag100 -n app-2 -- ip address show dev net1 | grep 'inet 10.1'
    inet 10.1.100.20/24 brd 10.1.100.255 scope global net1
```

### install net-attach-def for cfos

```bash
kubectl create namespace cfostest
k apply -f nad_10_1_200_252_cfos.yaml -n cfostest
k apply -f nad_10_1_100_252_cfos.yaml -n cfostest
```

### Deploy cfos 
```bash
k apply -f 01_create_cfos_account.yaml -n cfostest
k apply -f ./../imagepullsecret.yaml -n cfostest
k apply -f ./../cfos_license.yaml -n cfostest
k apply -f 02_create_cfos_deployment.yaml -n cfostest
```


### Check cFOS IP

```
k exec -it po/cfos-deployment-2-wjlg6 -n cfostest -- sh
# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
3: eth0@if11: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc noqueue state UP group default 
    link/ether f2:0f:1a:16:b0:a1 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 10.244.48.4/32 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::f00f:1aff:fe16:b0a1/64 scope link 
       valid_lft forever preferred_lft forever
4: net1@if2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default 
    link/ether ca:fe:c0:ff:00:02 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 10.1.200.252/24 brd 10.1.200.255 scope global net1
       valid_lft forever preferred_lft forever
    inet6 fe80::c8fe:c0ff:feff:2/64 scope link 
       valid_lft forever preferred_lft forever
5: net2@if2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default 
    link/ether ca:fe:c0:ff:01:00 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 10.1.100.252/24 brd 10.1.100.255 scope global net2
       valid_lft forever preferred_lft forever
    inet6 fe80::c8fe:c0ff:feff:100/64 scope link 
       valid_lft forever preferred_lft forever
# 

```

### Check the connectivity between pod1 application to pod2 application 

```bash
k exec -it po/diag200 -n app-1 -- ping 10.1.100.20
PING 10.1.100.20 (10.1.100.20) 56(84) bytes of data.
64 bytes from 10.1.100.20: icmp_seq=1 ttl=63 time=0.110 ms
64 bytes from 10.1.100.20: icmp_seq=2 ttl=63 time=0.073 ms
64 bytes from 10.1.100.20: icmp_seq=3 ttl=63 time=0.077 ms
```
and
```
k exec -it po/diag100 -n app-2 -- ping 10.1.200.20
PING 10.1.200.20 (10.1.200.20) 56(84) bytes of data.
64 bytes from 10.1.200.20: icmp_seq=1 ttl=63 time=0.069 ms
64 bytes from 10.1.200.20: icmp_seq=2 ttl=63 time=0.068 ms
```

### Config firewall policy on cFOS with configmap
```
k apply -f net1net2cmfirewallpolicy.yaml -n cfostest
```


### test ips feature 

without carry ips signature
```bash
$ k exec -it po/diag100 -n app-2 -- curl  -I  http://10.1.200.20
HTTP/1.1 200 OK
Server: nginx/1.18.0
Date: Fri, 17 May 2024 02:20:05 GMT
Content-Type: text/html
Content-Length: 1558
Last-Modified: Fri, 17 May 2024 01:57:20 GMT
Connection: keep-alive
ETag: "6646b980-616"
Accept-Ranges: bytes
```

with ips sigutrue
```bash
 k exec -it po/diag100 -n app-2  -- curl  -H "User-Agent: () { :; }; /bin/ls" http://10.1.200.20

```
got no reply or timeout 


### Check cFOS ips log

```
XIANPINGs-MacBook-Air:east-west i$ k exec -it po/cfos-deployment-2-wjlg6 -n cfostest -- sh
# cd /var/log/log
# tail ips.0
date=2024-05-17 time=02:23:35 eventtime=1715912615 tz="+0000" logid="0419016384" type="utm" subtype="ips" eventtype="signature" level="alert" severity="critical" srcip=10.1.100.20 dstip=10.1.200.20 srcintf="net2" dstintf="net1" sessionid=1 action="dropped" proto=6 service="HTTP" policyid=11 attack="Bash.Function.Definitions.Remote.Code.Execution" srcport=39810 dstport=80 hostname="10.1.200.20" url="/" direction="outgoing" attackid=39294 profile="high_security" incidentserialno=134217729 msg="applications3: Bash.Function.Definitions.Remote.Code.Execution"
```
