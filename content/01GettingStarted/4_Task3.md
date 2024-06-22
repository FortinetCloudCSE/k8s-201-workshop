---
title: "Task 3 Create cFOS container image"
weight: 3
---

### Task Create cFOS container image
This is optional, only if you want create your own cfos docker image. otherwise skip this.
if you want create your cfos docker image. you need use a linux client with docker client 

**build cfos image and push to repo**

Download cFOS image from Fortinet Website, once you got image.
```bash
wget -c https://storage.googleapis.com/my-bucket-cfos-384323/FOS_X64_DOCKER-v7-build0255-FORTINET.tar
```

build docker image 

```bash
docker load < FOS_X64_DOCKER-v7-build0231-FORTINET.tar
az acr create --name fortinetwandy --sku basic -g wandy
az acr login --name fortinetwandy
docker tag fos:latest  fortinetwandy.azurecr.io/cfos:255
docker push fortinetwandy.azurecr.io/cfos:255

```

**generate 24 hours valid temp token** 

```bash
output=$(az acr login -n fortinetwandy --expose-token)

# Parse the output to extract accessToken and loginServer
accessToken=$(echo $output | jq -r '.accessToken')
loginServer=$(echo $output | jq -r '.loginServer')

# Print the variables to verify
echo "Access Token: $accessToken"
echo "Login Server: $loginServer"
```
### Create aks cluster 
create aks cluster
append "--enable-node-public-ip" if you want assign a public ip to worker node"

```bash
#!/bin/bash -x
owner="tecworkshop"
alias k="kubectl"
currentUser=$(az account show --query user.name -o tsv)
resourceGroupName=$(az group list --query "[?tags.UserPrincipalName=='$currentUser'].name" -o tsv)
location=$(az group show --name $resourceGroupName --query location -o tsv)
scriptDir="$HOME"
cfosimage="fortinetwandy.azurecr.io/cfos:255"
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
### create image pull secret for k8s 
use below script to create imagepullsecret, replace acessToken below with real token 
```bash
loginServer="fortinetwandy.azurecr.io"
accessToken="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6IklFTVI6TTdFRzpVV1JUOllIUEs6T1BZUTpZQjZNOjVUQ1M6S1RYRjpaQUhDOlZIRUw6RVVMUTo0SU1LIn0.eyJqdGkiOiIyMzBjYWYxNS1hMmVhLTQzNTItYWJkNy1kNWY1OGFjZWRjMDkiLCJzdWIiOiJ3YW5keUBmb3J0aW5ldC11cy5jb20iLCJuYmYiOjE3MTkwMzMxNjEsImV4cCI6MTcxOTA0NDg2MSwiaWF0IjoxNzE5MDMzMTYxLCJpc3MiOiJBenVyZSBDb250YWluZXIgUmVnaXN0cnkiLCJhdWQiOiJmb3J0aW5ldHdhbmR5LmF6dXJlY3IuaW8iLCJ2ZXJzaW9uIjoiMS4wIiwicmlkIjoiMzkzYzEzYTJlNjE4NDk4ZDk0NDliMWUyZjRmMmUzMGQiLCJncmFudF90eXBlIjoicmVmcmVzaF90b2tlbiIsImFwcGlkIjoiMDRiMDc3OTUtOGRkYi00NjFhLWJiZWUtMDJmOWUxYmY3YjQ2IiwidGVuYW50IjoiOTQyYjgwY2QtMWIxNC00MmExLThkY2YtNGIyMWRlY2U2MWJhIiwicGVybWlzc2lvbnMiOnsiYWN0aW9ucyI6WyJyZWFkIiwid3JpdGUiLCJkZWxldGUiLCJtZXRhZGF0YS9yZWFkIiwibWV0YWRhdGEvd3JpdGUiLCJkZWxldGVkL3JlYWQiLCJkZWxldGVkL3Jlc3RvcmUvYWN0aW9uIl19LCJyb2xlcyI6W119.OhJmw_wKmeQiobiV7sZE1GhulW1rErKv-7-aKfe0P7PlvAzMpIaOB-mVW-J9a9u0fM7xg2ZUYWEZwWsuchoTaD_2k8-zUteIefSvgC-MFJXQsg2FVQ7W3J0qETqChEP4S9mMyUk8RbfnY4B-A2u9vKgi5nO9QuzIc5SYifPocbbxNYZGp5cqibaZ_CK5Qs846M9miChTQj0eHYZ5QYYVs33RvWrMiiSzCDTC3fBmFgTeW1S_zVX2OKTIbQPPxnKC34q27gCS8knTyI4VkjvwZ5TN7Pl9hbgxJzRKcMefgj8HaR-9CdAQ6FwF0w3qUpHIAP9q5u3mVddkKGm2pVD39Q"
echo $accessToken
echo $loginServer 
kubectl create namespace cfostest
kubectl create secret -n cfostest docker-registry cfosimagepullsecret \
    --docker-server=$loginServer \
    --docker-username=00000000-0000-0000-0000-000000000000 \
    --docker-password=$accessToken \
    --docker-email=wandy@fortinet.com
```


### Clone script from github

```bash
cd $HOME
git clone https://github.com/FortinetCloudCSE/k8s-201-workshop.git
```


