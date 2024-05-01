# purpuse

this is the demo for egress security. application pod will config explict route to 1.1.1.1 with nexthop point to cfos net1 interface.  the cfos net1 interface is created by multus CNI with proxy to bridge CNI. 

from application pod, only traffic that destinated to 1.1.1.1 will be inspected by cFOS. rest of traffic will not be affected. 

```
./create_kubeadm_k8s_on_ubuntu22.sh

```
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
kubectl apply -f 02_create_cfos_deployment.yaml

```

# config cfos

```
kubectl apply -f 03_cfos_firewallpolicycm.yaml

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

