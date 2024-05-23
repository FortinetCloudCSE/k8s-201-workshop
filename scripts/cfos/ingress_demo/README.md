## create k8s cluster

```bash
cd $HOME/k8s-201-workshop/scripts/cfos/egress

./create_kubeadm_k8s_on_ubuntu22.sh
```
## install slb

```bash
./ingressmetallbforkubeadmk8s.sh
cd ./../cfos/ingress_demo
```

## deploy cfos

k create namespace cfostest
k apply -f cfos_license.yaml -n cfostest
k apply -f imagepullsecret.yaml -n cfostest
k apply -f dockerinterbeing.yaml -n cfostest

```bash
kubectl create -f 01_create_cfos_account.yaml  -n cfostest
kubectl create -f 02_create_cfos_deployment.yaml  -n cfostest
```

## deploy demoservice 
```bash
kubectl create -f 03_single.yaml   -n cfostest
./create_nginx_and_fileupload_application.sh
```

## run ingress controller
```bash
kubectl apply -f 04_deploy_cfos_controller.yaml
```

## check result
```bash
curl -k http://k8strainingmaster1.westus.cloudapp.azure.com:8888
```
## bug -255 version
```
echo "search default.svc.cluster.local svc.cluster.local cluster.local lrf3leckvz0etibe0tq2z2hrsd.dx.internal.cloudapp.net
nameserver 10.96.0.10
options ndots:5" > /data/etc/resolv.conf
```
