---
title: "Task 4 Appdenx - Build cFOS container image on Azure "
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

**generate 24 hours valid temp token for other one to use ** 

```bash
output=$(az acr login -n fortinetwandy --expose-token)

# Parse the output to extract accessToken and loginServer
accessToken=$(echo $output | jq -r '.accessToken')
loginServer=$(echo $output | jq -r '.loginServer')

# Print the variables to verify
echo "Access Token: $accessToken"
echo "Login Server: $loginServer"
```
## Delete all resource

```bash
rg=$(az group list --query "[?contains(name, '$(whoami)') && contains(name, 'workshop')].name" -o tsv) 
vmNames=$(az vm list -g $rg --query "[].name" -o tsv)
for vmName in $vmNames; do 
   az vm delete --name $vmName -g $rg --yes
done

diskNames=$(az disk list --resource-group "$rg" --query "[].name" -o tsv)
  for diskName in $diskNames; do
    az disk delete --name "$diskName" --resource-group $rg --yes
  done

nics=$(az network nic list -g $rg -o tsv)
for nic in $nics; do
    az network nic delete --name $nic -g $rg 
done

publicIps=$(az network public-ip list -g $rg -o tsv)
for publicIp in $publicIps; do 
    az network public-ip delete --name $publicIp -g $rg 
done

vnets=$(az network vnet list -g $rg -o tsv)
for vnet in $vnets; do
   az network vnet delete --name $vnet -g $rg
done


nsgs=$(az network nsg list -g $rg -o tsv)
for nsg in $nsgs; do
    az network nsg delete --name $nsg -g $rg 
done
```
