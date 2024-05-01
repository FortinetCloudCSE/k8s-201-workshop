# purpuse

this is the demo for egress security. application pod will config explict route to 1.1.1.1 with nexthop point to cfos net1 interface.  the cfos net1 interface is created by multus CNI with proxy to bridge CNI. 

from application pod, only traffic that destinated to 1.1.1.1 will be inspected by cFOS. rest of traffic will not be affected. 

# install self managed ks8 with calico cni as well as bridge and macvlan cni
macvlan and bridge shall come by default and placed in /opt/cni/bin
# install multus
```
./install_multus.sh
```
# create nad for application pod
```
kubectl apply -f  nad_1_1_1_1.yaml
```
# create nad for  cfos

```
kubectl apply -f nad_cfos.yaml
```

# create application pod
```
kubectl apply -f demo_application_pod.yaml
```

# create cfos pod
```
kubectl apply -f 01_create_cfos_account.yaml
kubectl apply -f cfos_license.yaml 
kubectl apply -f dockerinterbeing.yaml
kubectl apply -f cfos_pod.yaml

```

# config cfos
login cfos 
```
XIANPINGs-MacBook-Air:egress i$ k exec -it po/cfos -- sh
# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
3: eth0@if16: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc noqueue state UP group default 
    link/ether 7a:c7:8c:02:f5:43 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 10.244.166.11/32 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::78c7:8cff:fe02:f543/64 scope link 
       valid_lft forever preferred_lft forever
4: net1@if2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default 
    link/ether ca:fe:c0:ff:00:02 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 10.1.200.252/24 brd 10.1.200.255 scope global net1
       valid_lft forever preferred_lft forever
    inet6 fe80::c8fe:c0ff:feff:2/64 scope link 
       valid_lft forever preferred_lft forever
# fcnsh
User: admin
Password: 

```
and paste below config 
```
config router static
    edit 10
        set dst 1.1.1.1/32
        set gateway 169.254.1.1
        set device "eth0"
    next
end


config firewall policy
    edit 10
        set name "tointernet"
        set srcintf "net1"
        set dstintf "eth0"
        set srcaddr "all"
        set dstaddr "all"
        set service "ALL"
        set nat enable
        set logtraffic all
    next
end

```

# check result

```
XIANPINGs-MacBook-Air:egress i$ k exec -it po/diag -- bash
bash-5.1# ip route get 1.1.1.1
1.1.1.1 via 10.1.200.252 dev net1 src 10.1.200.21 uid 0 
    cache 
bash-5.1# ping 1.1.1.1
PING 1.1.1.1 (1.1.1.1) 56(84) bytes of data.
64 bytes from 1.1.1.1: icmp_seq=1 ttl=53 time=2.43 ms
^C
--- 1.1.1.1 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 2.430/2.430/2.430/0.000 ms
bash-5.1# 
```
# check log on cfos

```
XIANPINGs-MacBook-Air:egress i$ k exec -it po/cfos -- sh 
# tail -f /var/log/log/traffic.0
date=2024-05-01 time=00:56:34 eventtime=1714524994 tz="+0000" logid="0000000013" type="traffic" subtype="forward" level="notice" srcip=10.1.200.21 identifier=52 dstip=1.1.1.1 sessionid=318530543 proto=1 action="accept" policyid=10 trandisp="noop" duration=455 sentbyte=35028 rcvdbyte=0 sentpkt=417 rcvdpkt=0
date=2024-05-01 time=01:03:44 eventtime=1714525424 tz="+0000" logid="0000000013" type="traffic" subtype="forward" level="notice" srcip=10.1.200.21 identifier=53 dstip=1.1.1.1 sessionid=670242919 proto=1 action="accept" policyid=10 trandisp="noop" duration=466 sentbyte=36708 rcvdbyte=36708 sentpkt=437 rcvdpkt=437
date=2024-05-01 time=01:08:51 eventtime=1714525731 tz="+0000" logid="0000000013" type="traffic" subtype="forward" level="notice" srcip=10.1.200.21 identifier=58 dstip=1.1.1.1 sessionid=3702929566 proto=1 action="accept" policyid=10 trandisp="noop" duration=0 sentbyte=0 rcvdbyte=0 sentpkt=0 rcvdpkt=0
```

