## create k8s cluster

```bash
$HOME/k8s-201-workshop/scripts/cfos/egress/create_kubeadm_k8s_on_ubuntu22.sh
```
## install slb

```bash
ingressmetallbforkubeadmk8s.sh
```

## deploy cfos

create license
create imagepullsecret

```bash
kubectl create namespace cfostest
kubectl create -f 01_create_cfos_account.yaml  -n cfostest
kubectl create -f 02_create_cfos_deployment.yaml  -n cfostest
```

## deploy demoservice 
```bash
kubectl create -f 03_single.yaml   -n cfostest
create_nginx_and_fileupload_application.sh
```

## run ingress controller
```bash
kubectl apply -f 04_deploy_cfos_controller.yaml
```

## check result
```bash
curl -k http://k8strainingmaster1.westus.cloudapp.azure.com:8888
```
