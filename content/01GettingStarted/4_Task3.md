---
title: "Task 2 - Get Kubernetes Ready"
linkTitle: "2-Get Kubernetes Ready"
weight: 3
---

In this chapter, we will:

- Retrieve the script from GitHub
- Prepare the Kubernetes environment
- Set necessary variables


### Clone script from github

```bash
cd $HOME
git clone https://github.com/FortinetCloudCSE/k8s-201-workshop.git
cd $HOME/k8s-201-workshop
git pull
cd $HOME
```

### Get K8S Ready

You have multiple options for setting up Kubernetes:

1. If you are using the [K8s-101 workshop environment](https://fortinetcloudcse.github.io/k8s-101-workshop/03_participanttasks/03_01_k8sinstall/03_01_02_k8sinstall.html), you can continue in the K8s-101 environment and choose [Option 1](/01gettingstarted/4_task3.html#option-1-continue-from-k8s-101-session).
2. If you are on the K8s-201 environment, choose [Option 2](/01gettingstarted/4_task3.html#option-2-create-self-managed-k8s) or [Option 3](/01gettingstarted/4_task3.html#option-3-create-aks) to start from K8s-201 directly.

#### Start Here

{{< tabs title="START HERE" icon="thumbtack" >}}
{{% tab title="Establish initialization variables" %}}


#### setup some variable (Mandatory step)

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
{{% /tab %}}

{{% tab title="Check variables" %}}

```bash
echo ResourceGroup  = $resourceGroupName
echo Location = $location
echo ScriptDir = $scriptDir
echo cFOS docker image = $cfosimage
echo cFOS NameSpace = $cfosnamespace
```
{{% /tab %}}

{{% tab title="Expected Output" style="info" %}}
  
```shell
 ResourceGroup = k8s54-k8s101-workshop
 Location = eastus
 ScriptDir = /home/k8s54
 cFOS docker image = fortinetwandy.azurecr.io/cfos:255
 cFOS NameSpace = cfostest
```
{{% /tab %}}
{{< /tabs >}}

{{% expand title="**Option 1: Continue from K8S-101 Session...**" %}}
#### Option 1: Continue from K8S-101 Session

If you are continuing from the K8s-101-workshop, you should already have Kubernetes installed. Hence continue with Option1. if you dont have lab from K8s-101-workshop you can pick from Option2 or Option 3. 

**check your k8s**
{{< tabs title="MetalLB install" >}}
{{% tab title="Install" %}}

If this K8S is self-managed, you might not have MetalLB installed, and you need to install it.

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
{{% /tab %}}
{{% tab title="Verify your K8S" %}}
```bash
kubectl get node -o wide
```
{{% /tab %}}
{{% tab title="Expected Output" style="info" %}}
Both nodes should be in the Ready status.

```TableGen { wrap="true" }
NAME          STATUS   ROLES           AGE     VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION     CONTAINER-RUNTIME
node-worker   Ready    <none>          4m24s   v1.26.1   10.0.0.4      <none>        Ubuntu 22.04.4 LTS   6.5.0-1022-azure   cri-o://1.25.4
nodemaster    Ready    control-plane   9m30s   v1.26.1   10.0.0.5      <none>        Ubuntu 22.04.4 LTS   6.5.0-1022-azure   cri-o://1.25.4
```
{{% /tab %}}
{{< /tabs >}}

{{% /expand %}}

{{% expand title="**Option 2: Create Self-managed K8S...**" %}}

#### Option 2: Create Self-managed K8S

If you are in the K8s-201 workshop, you can create a self-managed Kubernetes cluster, which will take around 10 minutes. If you prefer to use AKS instead of a self-managed cluster, proceed to Option 3. 

The Self managed cluster is where you wont use Azure based Kubernetes Service but build Kubernetes from scratch on Linux vM's hosted in Azure. 

The self-managed Kubernetes cluster uses Calico as the CNI, which is the most common CNI in self-managed environments. Refer to the [K8s Network](/06networkingbasics.html) section for more information about Kubernetes networking.

{{< tabs title="Self Managed K8S" >}}
{{% tab title="Create Cluster" %}}
```bash
scriptDir="$HOME"
cd $HOME/k8s-201-workshop/scripts/cfos/egress
./create_kubeadm_k8s_on_ubuntu22.sh
cd $scriptDir
svcname=$(kubectl config view -o json | jq .clusters[0].cluster.server | cut -d "." -f 1 | cut -d "/" -f 3)
echo $svcname
```
{{% /tab %}}
{{% tab title="Check Status" %}}
```
kubectl get node -o wide
```
{{% /tab %}}
{{% tab title="Expected Output" style="info" %}}
```TableGen
NAME                        STATUS   ROLES           AGE     VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION     CONTAINER-RUNTIME
k8strainingmasterk8s511     Ready    control-plane   4m23s   v1.26.1   10.0.0.4      <none>        Ubuntu 22.04.4 LTS   6.5.0-1022-azure   cri-o://1.25.4
k8strainingworker-k8s51-1   Ready    <none>          102s    v1.26.1   10.0.0.5      <none>        Ubuntu 22.04.4 LTS   6.5.0-1022-azure   cri-o://1.25.4
```
{{% /tab %}}
{{< /tabs >}}

   You can ssh into both master node and worker node via domain name 
   - Use `az network public-ip list -o table` to find the public ip address of nodes.
   - For example, use ssh ubuntu@52.224.219.58 and ssh ubuntu@40.71.204.87 to ssh into both nodes.

{{< tabs title="Get Public IPs" >}}
{{% tab title="Command" %}}
```powershell
az network public-ip list -o table
```
{{% /tab %}}
{{% tab title="Expected Output" style="info" %}}
```TableGen
Name                               ResourceGroup          Location    Zones    Address        IdleTimeoutInMinutes    ProvisioningState
---------------------------------  ---------------------  ----------  -------  -------------  ----------------------  -------------------
k8strainingmaster-k8s51-1PublicIP  k8s51-k8s101-workshop  eastus               52.224.219.58  4                       Succeeded
k8strainingworker-k8s51-1PublicIP  k8s51-k8s101-workshop  eastus               40.71.204.87   4                       Succeeded
```
{{% /tab %}}
{{< /tabs >}}

### Check Calico Configuration on Self-Managed k8s 

cFOS Egress use case relies on CNI to route traffic from application container to cFOS, therefore, it is important to understand the CNI you are used in your k8s cluster. 

The Calico configuration used in self-managed Kubernetes runs in [overlay mode](https://docs.tigera.io/calico/latest/networking/configuring/vxlan-ipip?ref=qdnqn.com) , calico routes traffic using VXLAN for all traffic originating from a Calico enabled host, to all Calico networked containers and VMs within the IP pool. This setup means that pods do not share a subnet with the VNET, providing ample address space for the pods. Additionally, because cFOS requires IP forwarding, it is necessary to enable IP forwarding when configuring Calico.

Below you can find details on IP pools, encapsulation, container IP forwarding, and other related configurations.

{{< tabs title="Check Calico Config" >}}
{{% tab title="command" %}}
```bash
kubectl get installation default -o jsonpath="{.spec}" | jq .
```
{{% /tab %}}
{{% tab title="Expected Output" style="info" %}}
```json
{
  "calicoNetwork": {
    "bgp": "Disabled",
    "containerIPForwarding": "Enabled",
    "hostPorts": "Enabled",
    "ipPools": [
      {
        "blockSize": 24,
        "cidr": "10.224.0.0/16",
        "disableBGPExport": false,
        "encapsulation": "VXLAN",
        "natOutgoing": "Enabled",
        "nodeSelector": "all()"
      }
    ],
    "linuxDataplane": "Iptables",
    "multiInterfaceMode": "None",
    "nodeAddressAutodetectionV4": {
      "firstFound": true
    }
  },
  "cni": {
    "ipam": {
      "type": "Calico"
    },
    "type": "Calico"
  },
  "controlPlaneReplicas": 2,
  "flexVolumePath": "/usr/libexec/kubernetes/kubelet-plugins/volume/exec/",
  "kubeletVolumePluginPath": "/var/lib/kubelet",
  "nodeUpdateStrategy": {
    "rollingUpdate": {
      "maxUnavailable": 1
    },
    "type": "RollingUpdate"
  },
  "nonPrivileged": "Disabled",
  "variant": "Calico"
}
```
{{% /tab %}}
{{< /tabs >}}

- ssh into master node via domain name
```bash
masternodename="k8strainingmaster"-$(whoami)-1.${location}.cloudapp.azure.com
ssh ubuntu@$masternodename
```

- ssh into worker node via domain name

```bash
workernodename="k8strainingworker-$(whoami)-1.${location}.cloudapp.azure.com"
ssh ubuntu@$workernodename
```
or create a jumphost ssh client pod 
```bash
nodeip=$(kubectl get node -o jsonpath='{.items[0].status.addresses[0].address}')
echo $nodeip 
 
cat << EOF | tee sshclient.yaml 
apiVersion: v1
kind: Pod
metadata:
  name: ssh-jump-host
  labels:
    app: ssh-jump-host
spec:
  containers:
  - name: ssh-client
    image: alpine
    command: ["/bin/sh"]
    args: ["-c", "apk add --no-cache openssh && apk add --no-cache curl && tail -f /dev/null"]
    stdin: true
    tty: true
EOF

kubectl apply -f sshclient.yaml
echo wait for pod ready, use Ctr-c to break
kubectl get pod  ssh-jump-host -w
```
then copy ssh key  into jumphost client pod

```bash
kubectl exec -it ssh-jump-host -- sh -c "mkdir -p ~/.ssh"
kubectl cp ~/.ssh/id_rsa default/ssh-jump-host:/root/.ssh/id_rsa
kubectl exec -it ssh-jump-host -- sh -c 'chmod 600 /root/.ssh/id_rsa'
```
and then use 

`kubectl exec -it ssh-jump-host -- ssh ubuntu@$masternodename` ssh into master node.

or 

`kubectl exec -it ssh-jump-host -- ssh ubuntu@$workernodename` ssh into worker node.

After you ssh into node. you can use `cat /etc/cni/net.d/10-calico.conflist` to check CNI configuration.

{{% /expand %}}

{{% expand title="**Option 3: Create AKS ...**" %}}

#### Option 3: Create AKS 

If you prefer AKS(Azure Kubernetes Service), use this option. This option will deploy an AKS cluster along with Kubernetes already installed. Use the script below to create a single-node cluster.

{{< tabs title="AKS K8s Deployment" icon="thumbtack" >}}
{{% tab title="Start Here" %}}


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

{{% /tab %}}
{{% tab title ="Check your AKS cluster" %}}
```bash
kubectl get node -o wide
```
{{% /tab %}}
{{% tab title="Expected Output" style="info" %}}

You will only see a single worker node because this is a managed Kubernetes cluster (AKS), and the master nodes are hidden from you. Additionally, you may notice that the container runtime is **containerd**, which differs from self-managed Kubernetes clusters where the container runtime is typically **cri-o**.
```TableGen
NAME                             STATUS   ROLES   AGE   VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
aks-worker-39339143-vmss000000   Ready    agent   47m   v1.28.9   10.224.0.4    <none>        Ubuntu 22.04.4 LTS   5.15.0-1066-azure   containerd://1.7.15-1
```

{{% /tab %}}
{{< /tabs >}}


### ssh into your worker node.

If your k8s node does not have public ip assigned, you can SSH via internal IP with jumphost container.

For self-managed Kubernetes clusters, you can SSH into both the master and worker nodes. However, for AKS (Azure Kubernetes Service), you can only SSH into the worker nodes. Below is an example of how to SSH into an AKS worker node with internal ip.

You can SSH into a worker node via a public IP or through an internal IP using a jump host. The script below demonstrates how to SSH into a worker node using a jump host pod.


{{< tabs title="Login to Cluster Worker Node" icon="thumbtack" >}}

{{% tab title="Create Jump Host Pod" %}}
```bash session
nodeip=$(kubectl get node -o jsonpath='{.items[0].status.addresses[0].address}')
echo $nodeip 
 
cat << EOF | tee sshclient.yaml 
apiVersion: v1
kind: Pod
metadata:
  name: ssh-jump-host
  labels:
    app: ssh-jump-host
spec:
  containers:
  - name: ssh-client
    image: alpine
    command: ["/bin/sh"]
    args: ["-c", "apk add --no-cache openssh && apk add --no-cache curl && tail -f /dev/null"]
    stdin: true
    tty: true
EOF

kubectl apply -f sshclient.yaml
echo wait for pod ready, use Ctr-c to break
kubectl get pod  ssh-jump-host -w
```

after pod show running  then shell into to use ssh


Once You see **Status** as **Running**, you can press <kbd>CTRL</kbd>**+**<kbd>c</kbd> to end the wait command, and proceed

{{% /tab %}}
{{% tab title="enter Pod Shell and SSH into worker node" %}}
```bash
kubectl exec -it ssh-jump-host -- sh -c "mkdir -p ~/.ssh"
kubectl cp ~/.ssh/id_rsa_tecworkshop default/ssh-jump-host:/root/.ssh/id_rsa
kubectl exec -it ssh-jump-host -- sh -c 'chmod 600 /root/.ssh/id_rsa'
kubectl exec -it po/ssh-jump-host -- ssh azureuser@$nodeip
```
{{% /tab %}}
{{% tab title="Expected Output" style="info" %}}
You'll see a CLI prompt for the worker node
```commandline
azureuser@aks-worker-32004615-vmss000000:~$ 
```


- Useful Worker Node Commands
  - `sudo crictl version` check runtime version
  - `journalctl -f -u containerd` check containerd log
  - `sudo cat /etc/cni/net.d/10-azure.conflist` check cni config etc.,
  - `journalctl -f -u kubelet` check kubelet log
- Type <kbd>exit</kbd> to exit from worker node back to azure shell.
  - you can also use:
    - <kbd>CTRL</kbd>**+**<kbd>c</kbd>**+**<kbd>d</kbd>

{{% /tab %}}
{{< /tabs >}}

{{% /expand %}}

### Summary

Your preferred Kubernetes setup is now ready, and you are prepared to move on to the next task.



