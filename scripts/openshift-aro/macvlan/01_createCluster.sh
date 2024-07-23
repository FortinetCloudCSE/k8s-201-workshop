#!/bin/bash -x

az provider register -n Microsoft.RedHatOpenShift --wait 
az provider register -n Microsoft.Compute --wait
az provider register -n Microsoft.Storage --wait

AROCLUSTERNAME="wandy-openshift4Cluster"
RESOURCEGROUP="wandy-aro-cluster"
LOCATION="eastus"
VMSIZE="Standard_D4s_v3"

echo "start deploy" 
echo $(date)
az group create --name $AROCLUSTERNAME --location $LOCATION

az network vnet create --resource-group $AROCLUSTERNAME --name myVnet --address-prefixes 10.0.0.0/16 --subnet-name master-subnet --subnet-prefix 10.0.0.0/24

az network vnet subnet create --resource-group $AROCLUSTERNAME --vnet-name myVnet --name worker-subnet --address-prefixes 10.0.1.0/24

az network vnet subnet update --name master-subnet --resource-group $AROCLUSTERNAME --vnet-name myVnet --disable-private-link-service-network-policies true

az aro create --resource-group $AROCLUSTERNAME --name $AROCLUSTERNAME --vnet myVnet --master-subnet master-subnet --worker-subnet worker-subnet --worker-vm-size $VMSIZE --worker-count 3

echo "deploy done"
echo $(date)

# Get credentials
credentials=$(az aro list-credentials --name $AROCLUSTERNAME -g $AROCLUSTERNAME)
username=$(echo $credentials | jq -r '.kubeadminUsername')
password=$(echo $credentials | jq -r '.kubeadminPassword')

# Set up kubeconfig
apiServer=$(az aro show --name $AROCLUSTERNAME --resource-group $AROCLUSTERNAME --query "apiserverProfile.url" -o tsv)
oc login $apiServer -u $username -p $password

# Print out credentials
echo "Kubeadmin Username: $username"
echo "Kubeadmin Password: $password"

az aro show --name $AROCLUSTERNAME --resource-group $AROCLUSTERNAME --query "consoleProfile.url"

