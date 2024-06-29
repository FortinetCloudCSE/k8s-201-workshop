---
title: "Task 3  Get Kubernetes Ready"
weight: 3
---

In this chapter, we will do 

- Get K8S ready
- Get the script from github 
- Set some Variable 


### Get K8S ready

You have mutliple option for setup K8S:

1.  if you are on k8s-101 environment, you can continue to this k8s-101 environment and choose [Option 1](/01gettingstarted/4_task3.html#option-1--continue-from-k8s-101-session). 
2.  if you are on k8s-201 environment, choose [option 2](/01gettingstarted/4_task3.html#option-2-create-self-managed-k8s)  or [option 3](/01gettingstarted/4_task3.html#option-3-create-aks)  start from k8s-201 directly 


#### Option 1 : Continue from K8S-101 session 

if you are continue from k8s-101 session, you shall already have k8s installed. 

**check your k8s**

```bash
kubectl get node -o wide

```
you shall have a K8S ready 

**setup some variable** 
```bash
owner="tecworkshop"
alias k="kubectl"
currentUser=$(az account show --query user.name -o tsv)
resourceGroupName=$(az group list --query "[?contains(name, '$(whoami)') && contains(name, 'workshop')].name" -o tsv)
location=$(az group show --name $resourceGroupName --query location -o tsv)
scriptDir="$HOME"
svcname=$(whoami)-$owner
cfosimage="fortinetwandy.azurecr.io/cfos:255"
cfosnamespace="cfostest"

cat << EOF | tee > $HOME/variable.sh
#!/bin/bash -x
owner="tecworkshop"
alias k="kubectl"
currentUser=$(az account show --query user.name -o tsv)
resourceGroupName=$(az group list --query "[?contains(name, '$(whoami)') && contains(name, 'workshop')].name" -o tsv)
location=$(az group show --name $resourceGroupName --query location -o tsv)
scriptDir="$HOME"
svcname=$(whoami)-$owner
cfosimage="fortinetwandy.azurecr.io/cfos:255"
cfosnamespace="cfostest"
EOF
echo location=$location >> $HOME/variable.sh
echo owner=$owner >> $HOME/variable.sh
echo scriptDir=$scriptDir >> $HOME/variable.sh
echo cfosimage=$cfosimage >> $HOME/variable.sh
echo resourceGroupName=$resourceGroupName >> $HOME/variable.sh
chmod +x $HOME/variable.sh
line='if [ -f "$HOME/variable.sh" ]; then source $HOME/variable.sh ; fi'
grep -qxF "$line" ~/.bashrc || echo "$line" >> ~/.bashrc
source $HOME/variable.sh
$HOME/variable.sh
if [ -f $HOME/.ssh/known_hosts ]; then
grep -qxF "$vm_name" "$HOME/.ssh/known_hosts"  && ssh-keygen -R "$vm_name"
fi

```
if this k8s is self-managed k8s, then you might not have metallb install , you need install that .

**install metallb**
```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.3/config/manifests/metallb-native.yaml
kubectl rollout status deployment controller -n metallb-system

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
kubectl apply -f metallbippool.yaml 
```
**Verify your environement**

```bash
kubectl get node -o wide
```
Both node shall in Ready status
```
NAME          STATUS   ROLES           AGE     VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION     CONTAINER-RUNTIME
node-worker   Ready    <none>          4m24s   v1.26.1   10.0.0.4      <none>        Ubuntu 22.04.4 LTS   6.5.0-1022-azure   cri-o://1.25.4
nodemaster    Ready    control-plane   9m30s   v1.26.1   10.0.0.5      <none>        Ubuntu 22.04.4 LTS   6.5.0-1022-azure   cri-o://1.25.4
```
check whether any of below variable is empty. 

```bash
echo ReousrceGroup  = $resourceGroupName
echo Location = $location
echo ScriptDir = $scriptDir
echo cFOS docker image = $cfosimage
echo cFOS NameSpace= $cfosnamespace
```

you shall see result like

```
ReousrceGroup = k8s54-k8s101-workshop
Location = eastus
ScriptDir = /home/k8s54
cFOS docker image = fortinetwandy.azurecr.io/cfos:255
cFOS Name Space= cfostest
```

#### Option 2: Create Self-managed k8s

if you are on K8s-201 workshop, you can directly create a self-managed k8s, it will take around 10 minutes.
if you want use AKS instead self-managed k8s, skip this. 

```bash
scriptDir="$HOME"
cd $HOME/k8s-201-workshop/scripts/cfos/egress
./create_kubeadm_k8s_on_ubuntu22.sh
cd $scriptDir
svcname=$(kubectl config view -o json | jq .clusters[0].cluster.server | cut -d "." -f 1 | cut -d "/" -f 3)
echo $svcname
```

#### Option 3: Create AKS 

if you do not want use self-managed k8s, you can use AKS instead. 

below script will create single node AKS cluster. 


{{% notice style="tip" %}}
append "--enable-node-public-ip" if you want assign a public ip to worker node" ,without public-ip for worker node, container will not able to use ping to reach internet
{{% /notice %}}

```bash
#!/bin/bash -x
owner="tecworkshop"
alias k="kubectl"
currentUser=$(az account show --query user.name -o tsv)
#resourceGroupName=$(az group list --query "[?tags.UserPrincipalName=='$currentUser'].name" -o tsv)
resourceGroupName=$(az group list --query "[?contains(name, '$(whoami)') && contains(name, 'workshop')].name" -o tsv)
location=$(az group show --name $resourceGroupName --query location -o tsv)
scriptDir="$HOME"
svcname=$(whoami)-$owner
cfosimage="fortinetwandy.azurecr.io/cfos:255"
cfosnamespace="cfostest"
echo "Using resource group $resourceGroupName in location $location"

cat << EOF | tee > $HOME/variable.sh
#!/bin/bash -x
alias k="kubectl"
scriptDir="$HOME"
aksVnetName="AKS-VNET"
aksClusterName=$(whoami)-aks-cluster
rsakeyname="id_rsa_tecworkshop"
remoteResourceGroup="MC"_${resourceGroupName}_$(whoami)-aks-cluster_${location} 
EOF
echo location=$location >> $HOME/variable.sh
echo owner=$owner >> $HOME/variable.sh
echo resourceGroupName=$resourceGroupName >> $HOME/variable.sh
echo cfosimage=$cfosimage >> $HOME/variable.sh
echo scriptDir=$scriptDir >> $HOME/variable.sh
echo cfosnamespace=$cfosnamespace >> $HOME/variable.sh

chmod +x $HOME/variable.sh
line='if [ -f "$HOME/variable.sh" ]; then source $HOME/variable.sh ; fi'
grep -qxF "$line" ~/.bashrc || echo "$line" >> ~/.bashrc
source $HOME/variable.sh
$HOME/variable.sh

az network vnet create -g $resourceGroupName  --name  $aksVnetName --location $location  --subnet-name aksSubnet --subnet-prefix 10.224.0.0/24 --address-prefix 10.224.0.0/16

aksSubnetId=$(az network vnet subnet show \
  --resource-group $resourceGroupName \
  --vnet-name $aksVnetName \
  --name aksSubnet \
  --query id -o tsv)
echo $aksSubnetId


[ ! -f ~/.ssh/$rsakeyname ] && ssh-keygen -t rsa -b 4096 -q -N "" -f ~/.ssh/$rsakeyname

az aks create \
    --name ${aksClusterName} \
    --node-count 1 \
    --vm-set-type VirtualMachineScaleSets \
    --network-plugin azure \
    --location $location \
    --service-cidr  10.96.0.0/16 \
    --dns-service-ip 10.96.0.10 \
    --nodepool-name worker \
    --resource-group $resourceGroupName \
    --kubernetes-version 1.28.9 \
    --vnet-subnet-id $aksSubnetId \
    --ssh-key-value ~/.ssh/${rsakeyname}.pub
az aks get-credentials -g  $resourceGroupName -n ${aksClusterName} --overwrite-existing

```

**check your AKS**
```bash
kubectl get node -o wide
```

you shall see single worker node only. because this is a managed k8s, the master node is hidden from you. you might also noticed that the container runtime is **containerd**. 

```
NAME                             STATUS   ROLES   AGE   VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
aks-worker-39339143-vmss000000   Ready    agent   47m   v1.28.9   10.224.0.4    <none>        Ubuntu 22.04.4 LTS   5.15.0-1066-azure   containerd://1.7.15-1
```

