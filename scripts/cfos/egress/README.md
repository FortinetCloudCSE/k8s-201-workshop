# install self managed ks8 with calico cni
# install cni binary
this cni binary shall be installed during install k8s. if not. ssh into each of k8s node.
do 
```
CNI_PLUGINS_VERSION="v1.1.1"
    ARCH="amd64"
    DEST="/opt/cni/bin"
    sudo mkdir -p "$DEST"
    curl  --insecure --retry 3 --retry-connrefused -fL "https://github.com/containernetworking/plugins/releases/download/$CNI_PLUGINS_VERSION/cni-plugins-linux-$ARCH-$CNI_PLUGINS_VERSION.tgz" | sudo tar -C "$DEST" -xz
```
# install multus
```
   cd /home/ubuntu
   git clone -b v3.9.3  https://github.com/intel/multus-cni.git
#   sed -i 's/multus-conf-file=auto/multus-conf-file=\/tmp\/multus-conf\/70-multus.conf/g' /home/ubuntu/multus-cni/deployments/multus-daemonset.yml
   sed -i 's/stable/v3.9.3/g' /home/ubuntu/multus-cni/deployments/multus-daemonset.yml
   cat /home/ubuntu/multus-cni/deployments/multus-daemonset.yml | kubectl --kubeconfig /home/ubuntu/.kube/config apply -f -

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
kubectl apply -f cfos_pod.yaml
```

# config cfos
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

